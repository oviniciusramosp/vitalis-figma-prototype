import SwiftUI
import MetalKit

/// Native rendering of the Figma mesh shader (128:7746), with stable paper grain
/// and subtle, sensor-driven parallax independent of the foreground interface.
/// The original WGSL/TypeScript source is retained in DesignReference.
struct PrototypeBackground: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = BackgroundMotion()
    @State private var isVisible = false

    var body: some View {
        FigmaMeshSurface(motion: motion)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear {
                isVisible = true
                synchronizeMotion()
            }
            .onDisappear {
                isVisible = false
                motion.stop()
            }
            .onChange(of: scenePhase) { _, _ in synchronizeMotion() }
            .onChange(of: reduceMotion) { _, _ in synchronizeMotion() }
    }

    private func synchronizeMotion() {
        if isVisible && scenePhase == .active && !reduceMotion {
            motion.start()
        } else {
            motion.stop()
        }
    }
}

/// Internal texture tuning: sRGB grain amplitude and a fixed, exactly representable seed.
private enum BackgroundTexture {
    static let grainAmplitude: Float = 0.024
    static let grainSeed: Float = 4171
}

private struct FigmaMeshSurface: UIViewRepresentable {
    var motion: BackgroundMotion

    func makeCoordinator() -> MeshRenderer { MeshRenderer() }

    func makeUIView(context: Context) -> MTKView {
        let view = MeshSurfaceView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.isOpaque = true
        view.clearColor = MTLClearColorMake(0.42, 0.42, 0.42, 1)
        view.backgroundColor = UIColor(white: 0.42, alpha: 1)
        view.maximumCadenceChanged = { [weak motion] maximum in motion?.maximumFramesPerSecond = maximum }
        let renderer = context.coordinator
        motion.onOffsetChange = { [weak renderer, weak view] offset in
            renderer?.offset = offset
            view?.setNeedsDisplay()
        }
        context.coordinator.prepare(view: view)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        if context.coordinator.offset != motion.offset {
            context.coordinator.offset = motion.offset
            view.setNeedsDisplay()
        }
    }
}

private final class MeshSurfaceView: MTKView {
    var maximumCadenceChanged: ((Int) -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        let maximum = window?.windowScene?.screen.maximumFramesPerSecond ?? 60
        preferredFramesPerSecond = maximum
        maximumCadenceChanged?(maximum)
    }
}

private final class MeshRenderer: NSObject, MTKViewDelegate {
    var offset: CGSize = .zero
    private static let preparationQueue = DispatchQueue(label: "vitalis.prototype.mesh.prepare", qos: .userInitiated)
    private static var sharedResources: Resources?
    private var resources: Resources?
    private var resolvedTexture: MTLTexture?
    private var canvasSize: CGSize = .zero

    private final class Resources {
        let queue: MTLCommandQueue
        let meshPipeline: MTLRenderPipelineState
        let resolvePipeline: MTLRenderPipelineState
        let parameters: MTLBuffer
        let indices: MTLBuffer
        let uniforms: MTLBuffer
        let indexCount: Int

        init(device: MTLDevice) throws {
            queue = device.makeCommandQueue()!
            // Use the shader compiled by Xcode; source is an off-main preview fallback.
            let library = try device.makeDefaultLibrary() ?? device.makeLibrary(source: MeshRenderer.metalSource, options: nil)
            let mesh = MTLRenderPipelineDescriptor()
            mesh.vertexFunction = library.makeFunction(name: "meshVertex")
            mesh.fragmentFunction = library.makeFunction(name: "meshFragment")
            mesh.colorAttachments[0].pixelFormat = .rgba16Float
            mesh.rasterSampleCount = 4
            meshPipeline = try device.makeRenderPipelineState(descriptor: mesh)
            let resolve = MTLRenderPipelineDescriptor()
            resolve.vertexFunction = library.makeFunction(name: "resolveVertex")
            resolve.fragmentFunction = library.makeFunction(name: "resolveFragment")
            resolve.colorAttachments[0].pixelFormat = .bgra8Unorm
            resolvePipeline = try device.makeRenderPipelineState(descriptor: resolve)

            let tessellation = 190
            let side = tessellation + 1
            var points = [SIMD2<Float>]()
            points.reserveCapacity(side * side)
            for row in 0..<side {
                for column in 0..<side {
                    points.append(SIMD2(Float(column) / Float(tessellation), Float(row) / Float(tessellation)))
                }
            }
            var triangleIndices = [UInt32]()
            triangleIndices.reserveCapacity(tessellation * tessellation * 6)
            for row in 0..<tessellation {
                for column in 0..<tessellation {
                    let topLeft = UInt32(row * side + column)
                    let topRight = topLeft + 1
                    let bottomLeft = topLeft + UInt32(side)
                    let bottomRight = bottomLeft + 1
                    triangleIndices.append(contentsOf: [topLeft, bottomLeft, topRight, topRight, bottomLeft, bottomRight])
                }
            }
            indexCount = triangleIndices.count
            parameters = points.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count)! }
            indices = triangleIndices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count)! }
            var values = [SIMD4<Float>]()
            for row: Float in [0, 0.33, 0.67, 1] {
                for column: Float in [0, 0.33, 0.67, 1] {
                    values.append(SIMD4(column, row, 0, 0))
                }
            }
            values.append(contentsOf: MeshRenderer.colors.map { SIMD4($0.x, $0.y, $0.z, 1) })
            uniforms = values.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count)! }
        }
    }

    func prepare(view: MTKView) {
        guard let device = view.device else { return }
        Self.preparationQueue.async { [weak self, weak view] in
            do {
                if Self.sharedResources == nil { Self.sharedResources = try Resources(device: device) }
                let resources = Self.sharedResources
                DispatchQueue.main.async {
                    guard let self, let view else { return }
                    self.resources = resources
                    view.setNeedsDisplay()
                }
            } catch { print("Figma mesh setup failed: \(error)") }
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        resolvedTexture = nil
        canvasSize = .zero
        view.setNeedsDisplay()
    }

    func draw(in view: MTKView) {
        guard let resources,
              let device = view.device,
              let drawable = view.currentDrawable,
              let command = resources.queue.makeCommandBuffer() else { return }
        let size = CGSize(width: drawable.texture.width, height: drawable.texture.height)
        if resolvedTexture == nil || canvasSize != size {
            // Cache the original full mesh once. The smooth field uses half physical
            // resolution; the final pass still hashes every full resolution pixel.
            let width = max(1, Int(ceil(size.width * (449.695 / 402) * 0.5)))
            let height = max(1, Int(ceil(size.height * (977.696 / 874) * 0.5)))
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
            descriptor.textureType = .type2DMultisample
            descriptor.sampleCount = 4
            descriptor.storageMode = .private
            descriptor.usage = [.renderTarget]
            guard let multisample = device.makeTexture(descriptor: descriptor) else { return }
            descriptor.textureType = .type2D
            descriptor.sampleCount = 1
            descriptor.usage = [.renderTarget, .shaderRead]
            guard let resolved = device.makeTexture(descriptor: descriptor) else { return }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = multisample
            pass.colorAttachments[0].resolveTexture = resolved
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.setRenderPipelineState(resources.meshPipeline)
            encoder.setVertexBuffer(resources.parameters, offset: 0, index: 0)
            encoder.setVertexBuffer(resources.uniforms, offset: 0, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: resources.indexCount, indexType: .uint32, indexBuffer: resources.indices, indexBufferOffset: 0)
            encoder.endEncoding()
            resolvedTexture = resolved
            canvasSize = size
        }
        guard let resolvedTexture else { return }
        // xy = UV displacement, z = grain amplitude, w = seed. Both float4
        // buffers have an explicit, matching 16-byte Swift/Metal stride.
        var effects = SIMD4<Float>(
            Float(offset.width / max(view.bounds.width, 1)),
            Float(offset.height / max(view.bounds.height, 1)),
            BackgroundTexture.grainAmplitude, BackgroundTexture.grainSeed
        )
        var dimensions = SIMD4<Float>(Float(size.width), Float(size.height), 0, 0)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        if let encoder = command.makeRenderCommandEncoder(descriptor: pass) {
            encoder.setRenderPipelineState(resources.resolvePipeline)
            encoder.setFragmentTexture(resolvedTexture, index: 0)
            encoder.setFragmentBytes(&effects, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentBytes(&dimensions, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }
        command.present(drawable)
        command.commit()
    }

    // Point order p00,p10,p20,p30,p01,...,p33; original unrounded color values.
    private static let colors: [SIMD3<Float>] = [
        SIMD3(0.48867562413215637, 0.25798678398132324, 0.112982377409935),
        SIMD3(0.2705882489681244, 0.14901961386203766, 0.07450980693101883),
        SIMD3(0.13333334028720856, 0.10196078568696976, 0.0784313753247261),
        SIMD3(0.0941176488995552, 0.08627451211214066, 0.0784313753247261),
        SIMD3(0.12941177189350128, 0.10588235408067703, 0.08627451211214066),
        SIMD3(0.23137255012989044, 0.1568627506494522, 0.10980392247438431),
        SIMD3(0.21176470816135406, 0.12941177189350128, 0.08627451211214066),
        SIMD3(0.09803921729326248, 0.09019608050584793, 0.08235294371843338),
        SIMD3(0.11764705926179886, 0.0941176488995552, 0.08627451211214066),
        SIMD3(0.21960784494876862, 0.13333334028720856, 0.09803921729326248),
        SIMD3(0.18039216101169586, 0.12156862765550613, 0.09803921729326248),
        SIMD3(0.29002028703689575, 0.21271054446697235, 0.16513530910015106),
        SIMD3(0.4192270040512085, 0.19013459980487823, 0.0506870411336422),
        SIMD3(0.3677509129047394, 0.2612453103065491, 0.2079925239086151),
        SIMD3(0.12156862765550613, 0.09019608050584793, 0.062745101749897),
        SIMD3(0.07450980693101883, 0.05882352963089943, 0.0470588244497776)
    ]

    private static let metalSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct Uniforms { float4 values[32]; };
    struct MeshOutput { float4 position [[position]]; float4 color; };
    float2 catmull2(float2 a, float2 b, float2 c, float2 d, float t) {
        float t2=t*t, t3=t2*t;
        return 0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t2+(-a+3.0*b-3.0*c+d)*t3);
    }
    float4 catmull4(float4 a, float4 b, float4 c, float4 d, float t) {
        float t2=t*t, t3=t2*t;
        return 0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t2+(-a+3.0*b-3.0*c+d)*t3);
    }
    float srgbToLinearChannel(float value) {
        return value<=0.04045 ? value/12.92 : pow((value+0.055)/1.055,2.4);
    }
    float4 srgbToLinear(float4 color) {
        color=clamp(color,0.0,1.0);
        return float4(srgbToLinearChannel(color.r),srgbToLinearChannel(color.g),srgbToLinearChannel(color.b),color.a);
    }
    float2 segment(float value) {
        float scaled=clamp(value,0.0,1.0)*3.0;
        float index=min(floor(scaled),2.0);
        return float2(index,scaled-index);
    }
    int pointIndex(int column,int row) { return row*4+column; }
    float2 meshPosition(float2 parameter,constant Uniforms &uniforms) {
        float2 sx=segment(parameter.x), sy=segment(parameter.y);
        int ix=int(sx.x), iy=int(sy.x);
        int x0=max(ix-1,0),x1=ix,x2=ix+1,x3=min(ix+2,3);
        int y0=max(iy-1,0),y1=iy,y2=iy+1,y3=min(iy+2,3);
        float2 row0=catmull2(uniforms.values[pointIndex(x0,y0)].xy,uniforms.values[pointIndex(x1,y0)].xy,uniforms.values[pointIndex(x2,y0)].xy,uniforms.values[pointIndex(x3,y0)].xy,sx.y);
        float2 row1=catmull2(uniforms.values[pointIndex(x0,y1)].xy,uniforms.values[pointIndex(x1,y1)].xy,uniforms.values[pointIndex(x2,y1)].xy,uniforms.values[pointIndex(x3,y1)].xy,sx.y);
        float2 row2=catmull2(uniforms.values[pointIndex(x0,y2)].xy,uniforms.values[pointIndex(x1,y2)].xy,uniforms.values[pointIndex(x2,y2)].xy,uniforms.values[pointIndex(x3,y2)].xy,sx.y);
        float2 row3=catmull2(uniforms.values[pointIndex(x0,y3)].xy,uniforms.values[pointIndex(x1,y3)].xy,uniforms.values[pointIndex(x2,y3)].xy,uniforms.values[pointIndex(x3,y3)].xy,sx.y);
        return catmull2(row0,row1,row2,row3,sy.y);
    }
    float4 meshColor(float2 parameter,constant Uniforms &uniforms) {
        float2 sx=segment(parameter.x),sy=segment(parameter.y);
        int ix=int(sx.x),iy=int(sy.x);
        int x0=max(ix-1,0),x1=ix,x2=ix+1,x3=min(ix+2,3);
        int y0=max(iy-1,0),y1=iy,y2=iy+1,y3=min(iy+2,3);
        int offset=16;
        float4 row0=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y0)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y0)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y0)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y0)]),sx.y);
        float4 row1=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y1)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y1)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y1)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y1)]),sx.y);
        float4 row2=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y2)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y2)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y2)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y2)]),sx.y);
        float4 row3=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y3)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y3)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y3)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y3)]),sx.y);
        return clamp(catmull4(row0,row1,row2,row3,sy.y),0.0,1.0);
    }
    vertex MeshOutput meshVertex(uint id [[vertex_id]],device const float2 *parameters [[buffer(0)]],constant Uniforms &uniforms [[buffer(1)]]) {
        float2 position=meshPosition(parameters[id],uniforms);
        MeshOutput output;
        // Cache the complete shader node; the final pass applies its original crop.
        output.position=float4(position.x*2.0-1.0,1.0-position.y*2.0,0.0,1.0);
        output.color=meshColor(parameters[id],uniforms);
        return output;
    }
    fragment float4 meshFragment(MeshOutput input [[stage_in]]) { return input.color; }
    struct ResolveOutput { float4 position [[position]]; };
    vertex ResolveOutput resolveVertex(uint id [[vertex_id]]) {
        const float2 points[6]={float2(-1,-1),float2(1,-1),float2(-1,1),float2(-1,1),float2(1,-1),float2(1,1)};
        ResolveOutput output; output.position=float4(points[id],0,1); return output;
    }
    float linearToSrgbChannel(float value) {
        float safeValue=max(value,0.0);
        return safeValue<=0.0031308 ? safeValue*12.92 : 1.055*pow(safeValue,1.0/2.4)-0.055;
    }
    float grain(uint2 pixel,uint seed) {
        // Integer avalanche hash: physical pixel coordinates, no time or tilt input.
        uint value=pixel.x*1973u+pixel.y*9277u+seed*26699u;
        value=(value^(value>>16u))*0x7feb352du;
        value=(value^(value>>15u))*0x846ca68bu;
        value=value^(value>>16u);
        return float(value)*(1.0/4294967295.0)*2.0-1.0;
    }
    fragment float4 resolveFragment(ResolveOutput input [[stage_in]],texture2d<float> source [[texture(0)]],constant float4 &effects [[buffer(0)]],constant float4 &dimensions [[buffer(1)]]) {
        uint2 pixel=uint2(input.position.xy);
        float2 screenUV=input.position.xy/dimensions.xy;
        float2 meshUV=(screenUV-effects.xy-0.5)*float2(402.0/449.695,874.0/977.696)+0.5;
        meshUV.x-=0.04/449.695;
        constexpr sampler linearSampler(coord::normalized,address::clamp_to_edge,filter::linear);
        float4 color=source.sample(linearSampler,meshUV);
        float3 rgb=clamp(float3(linearToSrgbChannel(color.r),linearToSrgbChannel(color.g),linearToSrgbChannel(color.b)),0.0,1.0);
        // Figma's white Color blend keeps backdrop luminosity, then white Screen at 30%.
        float luminosity=dot(rgb,float3(0.30,0.59,0.11));
        float finalGray=clamp(luminosity*0.70+0.30+grain(pixel,uint(effects.w))*effects.z,0.0,1.0);
        return float4(finalGray,finalGray,finalGray,color.a);
    }
    """
}
