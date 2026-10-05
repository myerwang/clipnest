// Responsibility: isolated native Metal prototype: one original texture on a hinged paper mesh.
// Relationship: synthetic-only QA entry point; never general clipboard, app defaults, login or existing UI.
// Development status: prototype, not yet integrated into PanelView.
import AppKit
import Metal
import simd
import ImageIO
import UniformTypeIdentifiers

struct PaperRandom {
    var state: UInt64
    mutating func unit() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(Double(state >> 11) / Double(UInt64.max >> 11))
    }
}
struct PaperVertex { var position: SIMD4<Float>; var normal: SIMD4<Float>; var uv: SIMD4<Float> }
private struct PaperUniform { var camera: simd_float4x4; var light: simd_float4x4 }
struct PaperTemplate {
    let columns = 16, rows = 4
    var slopes: [Float] = [0]
    var angles: [Float] = [0]
    var phases: [Float] = [0]
    init(seed: UInt64) {
        var random = PaperRandom(state: seed)
        // Bounded parallel slanted hinges and ordered mountain/valley timing keep the fold readable
        // without the crossing introduced by independently random axes in the initial prototype.
        let slope = Float(random.unit() - 0.5) * 0.18
        let angle = 2.0 + Float(random.unit()) * 0.20
        for index in 1..<16 {
            slopes.append(slope)
            let positive = index % 2 != 0
            angles.append((positive ? 1 : -1) * (angle + (positive ? 0.01 : -0.01) + Float(random.unit()) * 0.008))
            phases.append((positive ? 0 : 0.04) + Float(random.unit()) * 0.02)
        }
        slopes.append(0); angles.append(0); phases.append(0)
    }
    func geometry(progress: Float, width: Float = 340, height: Float = 36) -> ([PaperVertex], [SIMD3<Float>]) {
        var transformations = [matrix_identity_float4x4]
        var transform = matrix_identity_float4x4
        func translation(_ point: SIMD3<Float>) -> simd_float4x4 {
            var result = matrix_identity_float4x4; result.columns.3 = SIMD4(point, 1); return result
        }
        for column in 1...columns {
            let x = -width / 2 + Float(column) * width / Float(columns)
            let hinge = SIMD3<Float>(x, 0, 0)
            let axis = simd_normalize(SIMD3<Float>(slopes[column], 1, 0))
            let local = min(1, max(0, (progress - phases[column]) / (1 - phases[column])))
            let eased = local * local * (3 - 2 * local)
            let rotation = simd_float4x4(simd_quatf(angle: angles[column] * eased, axis: axis))
            transform = transform * translation(hinge) * rotation * translation(-hinge)
            transformations.append(transform)
        }
        var positions: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = []
        for column in 0...columns {
            for row in 0...rows {
                let y = -height / 2 + Float(row) * height / Float(rows)
                let x = -width / 2 + Float(column) * width / Float(columns) + slopes[column] * y
                let world = transformations[column] * SIMD4<Float>(x, y, 0, 1)
                positions.append(SIMD3(world.x, world.y, world.z))
                uvs.append(SIMD2((x + width / 2) / width, 1 - (y + height / 2) / height))
            }
        }
        let low = positions.reduce(SIMD3<Float>(repeating: .infinity), simd_min)
        let high = positions.reduce(SIMD3<Float>(repeating: -.infinity), simd_max)
        let center = (low + high) / 2
        positions = positions.map { $0 - center }
        var vertices: [PaperVertex] = []
        for column in 0..<columns { for row in 0..<rows {
            let a = column * (rows + 1) + row, b = (column + 1) * (rows + 1) + row
            for triangle in [[a,b,b+1], [a,b+1,a+1]] {
                let n = simd_normalize(simd_cross(positions[triangle[1]] - positions[triangle[0]], positions[triangle[2]] - positions[triangle[0]]))
                for i in triangle { vertices.append(PaperVertex(position: SIMD4(positions[i], 1), normal: SIMD4(n, 0), uv: SIMD4(uvs[i].x,uvs[i].y,0,0))) }
            }
        } }
        return (vertices, positions)
    }
}

private func meshValidation(_ template: PaperTemplate) -> (intersections: Int, strain: Float) {
    var triples: [[Int]] = []
    for column in 0..<16 { for row in 0..<4 {
        let a = column * 5 + row, b = (column + 1) * 5 + row
        triples.append([a,b,b+1]); triples.append([a,b+1,a+1])
    } }
    let rest = template.geometry(progress:0).1
    var intersections = 0, strain: Float = 0
    func crosses(_ from: SIMD3<Float>, _ to: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Bool {
        let direction = to - from, e1 = b - a, e2 = c - a
        let h = simd_cross(direction,e2), determinant = simd_dot(e1,h)
        // Relative tolerance avoids unstable near-parallel segment/plane division.
        let scale = simd_length(direction) * simd_length(e1) * simd_length(e2)
        if abs(determinant) <= 1e-5 * scale { return false }
        let inverse = 1 / determinant, offset = from - a
        let u = inverse * simd_dot(offset,h)
        if u <= 1e-5 || u >= 1-1e-5 { return false }
        let q = simd_cross(offset,e1), v = inverse * simd_dot(direction,q)
        if v <= 1e-5 || u+v >= 1-1e-5 { return false }
        let t = inverse * simd_dot(e2,q)
        return t > 1e-5 && t < 1-1e-5
    }
    for step in 0...80 {
        let points = template.geometry(progress:Float(step)/80).1
        for triangle in triples {
            for edge in 0..<3 {
                let a=triangle[edge], b=triangle[(edge+1)%3]
                strain=max(strain,abs(simd_length(points[a]-points[b])/simd_length(rest[a]-rest[b])-1))
            }
        }
        for i in 0..<triples.count { for j in (i+1)..<triples.count {
            let a=triples[i],b=triples[j]
            if a.contains(where:{ b.contains($0) }) { continue }
            var hit=false
            for edge in 0..<3 {
                hit = hit || crosses(points[a[edge]],points[a[(edge+1)%3]],points[b[0]],points[b[1]],points[b[2]])
                hit = hit || crosses(points[b[edge]],points[b[(edge+1)%3]],points[a[0]],points[a[1]],points[a[2]])
            }
            if hit { intersections += 1 }
        } }
    }
    return (intersections,strain)
}

final class PaperGPU {
    static let shared = try? PaperGPU(transparent: true)
    let transparent: Bool
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let shadowPipeline: MTLRenderPipelineState
    let depthState: MTLDepthStencilState
    let texture: MTLTexture
    let color: MTLTexture
    let depth: MTLTexture
    let shadow: MTLTexture
    let vertices: MTLBuffer
    let readback: MTLBuffer
    let width = 1024, height = 480
    var milliseconds: [Double] = []
    init(transparent: Bool = false) throws {
        self.transparent = transparent
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw NSError(domain:"ClipNest.MeshQA", code:1, userInfo:[NSLocalizedDescriptionKey:"Metal unavailable"]) }
        self.device = device; self.queue = queue
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct V { float4 position; float4 normal; float4 uv; };
        struct U { float4x4 camera; float4x4 light; };
        struct O { float4 position [[position]]; float3 normal; float2 uv; float4 light; };
        vertex O paperVertex(uint id [[vertex_id]], constant V *v [[buffer(0)]], constant U &u [[buffer(1)]]) {
            O o; o.position=u.camera*v[id].position; o.normal=v[id].normal.xyz; o.uv=v[id].uv.xy; o.light=u.light*v[id].position; return o;
        }
        vertex O shadowVertex(uint id [[vertex_id]], constant V *v [[buffer(0)]], constant U &u [[buffer(1)]]) {
            O o; o.position=u.light*v[id].position; o.normal=v[id].normal.xyz; o.uv=v[id].uv.xy; o.light=o.position; return o;
        }
        fragment void shadowFragment(O in [[stage_in]], texture2d<float> original [[texture(0)]]) {
            constexpr sampler s(filter::linear,address::clamp_to_edge);
            if(original.sample(s,in.uv).a<0.08) discard_fragment();
        }
        fragment float4 paperFragment(O in [[stage_in]], texture2d<float> original [[texture(0)]], depth2d<float> shadows [[texture(1)]]) {
            constexpr sampler s(filter::linear,address::clamp_to_edge);
            constexpr sampler compare(filter::linear,address::clamp_to_edge,compare_func::less_equal);
            float4 base=original.sample(s,in.uv); if(base.a<0.02) discard_fragment();
            float3 n=normalize(in.normal), light=normalize(float3(-0.45,0.55,1));
            float diffuse=abs(dot(n,light));
            float3 lp=in.light.xyz/in.light.w; float2 uv=lp.xy*float2(0.5,-0.5)+0.5;
            float visible=0; for(int x=-1;x<=1;x++) for(int y=-1;y<=1;y++) visible+=shadows.sample_compare(compare,uv+float2(x,y)/512.0,lp.z-0.003);
            visible/=9; float shade=0.34+0.66*diffuse; shade*=0.64+0.36*visible;
            return float4(base.rgb*shade,base.a);
        }
        """
        let library = try device.makeLibrary(source: source, options: nil)
        let render = MTLRenderPipelineDescriptor(); render.vertexFunction = library.makeFunction(name:"paperVertex"); render.fragmentFunction = library.makeFunction(name:"paperFragment")
        render.colorAttachments[0].pixelFormat = .rgba8Unorm; render.depthAttachmentPixelFormat = .depth32Float
        render.colorAttachments[0].isBlendingEnabled = true; render.colorAttachments[0].sourceRGBBlendFactor = .one; render.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        render.colorAttachments[0].sourceAlphaBlendFactor = .one; render.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: render)
        let shadows = MTLRenderPipelineDescriptor(); shadows.vertexFunction = library.makeFunction(name:"shadowVertex"); shadows.fragmentFunction = library.makeFunction(name:"shadowFragment"); shadows.depthAttachmentPixelFormat = .depth32Float
        shadowPipeline = try device.makeRenderPipelineState(descriptor: shadows)
        let descriptor = MTLDepthStencilDescriptor(); descriptor.depthCompareFunction = .lessEqual; descriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: descriptor)!
        func target(_ format: MTLPixelFormat, _ w: Int, _ h: Int, usage: MTLTextureUsage) -> MTLTexture {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width:w, height:h, mipmapped:false)
            d.storageMode = .private; d.usage = usage; return device.makeTexture(descriptor:d)!
        }
        color = target(.rgba8Unorm,width,height,usage:[.renderTarget]); depth = target(.depth32Float,width,height,usage:[.renderTarget]); shadow = target(.depth32Float,512,512,usage:[.renderTarget,.shaderRead])
        vertices = device.makeBuffer(length: 32768 * MemoryLayout<PaperVertex>.stride, options:.storageModeShared)!
        readback = device.makeBuffer(length: width * height * 4, options:.storageModeShared)!
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:680,pixelsHigh:72,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:680*4,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
        let capsule = NSBezierPath(roundedRect:NSRect(x:2,y:2,width:676,height:68),xRadius:22,yRadius:22)
        NSColor(srgbRed:0.91,green:0.94,blue:0.98,alpha:1).setFill(); capsule.fill(); capsule.addClip()
        ("ClipNest · Same original text — fold, unfold" as NSString).draw(in:NSRect(x:26,y:22,width:628,height:32),withAttributes:[.font:NSFont.systemFont(ofSize:26),.foregroundColor:NSColor(srgbRed:0.14,green:0.20,blue:0.29,alpha:1)])
        NSGraphicsContext.restoreGraphicsState()
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:680,height:72,mipmapped:false)
        textureDescriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed; textureDescriptor.usage = .shaderRead
        texture = device.makeTexture(descriptor:textureDescriptor)!
        texture.replace(region:MTLRegionMake2D(0,0,680,72),mipmapLevel:0,withBytes:bitmap.bitmapData!,bytesPerRow:680*4)
    }
    func setOriginal(_ image: CGImage) {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:680,pixelsHigh:72,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:680*4,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
        NSImage(cgImage:image,size:NSSize(width:680,height:72)).draw(in:NSRect(x:0,y:0,width:680,height:72))
        NSGraphicsContext.restoreGraphicsState()
        texture.replace(region:MTLRegionMake2D(0,0,680,72),mipmapLevel:0,withBytes:bitmap.bitmapData!,bytesPerRow:680*4)
    }
    func render(_ template: PaperTemplate, progress: Float) throws -> CGImage {
        try render(mesh: template.geometry(progress:progress).0)
    }
    func render(mesh: [PaperVertex]) throws -> CGImage {
        let tick = CACurrentMediaTime()
        precondition(mesh.count <= 32768)
        mesh.withUnsafeBytes { vertices.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count) }
        var camera = matrix_identity_float4x4
        camera.columns.0 = SIMD4(1/256.0,0,0,0); camera.columns.1=SIMD4(0,1/120.0,0,0); camera.columns.2=SIMD4(0,0,-1/700.0,0); camera.columns.3=SIMD4(0,0,0.5,1)
        let forward = simd_normalize(SIMD3<Float>(-0.45,0.55,1)), right = simd_normalize(simd_cross(SIMD3<Float>(0,1,0),forward)), up = simd_cross(forward,right)
        var light = matrix_identity_float4x4
        light.columns.0=SIMD4(right.x/200,up.x/200,-forward.x/700,0); light.columns.1=SIMD4(right.y/200,up.y/200,-forward.y/700,0); light.columns.2=SIMD4(right.z/200,up.z/200,-forward.z/700,0); light.columns.3=SIMD4(0,0,0.5,1)
        var uniform = PaperUniform(camera:camera,light:light)
        guard let command = queue.makeCommandBuffer() else { fatalError("GPU command unavailable") }
        let shadowPass = MTLRenderPassDescriptor(); shadowPass.depthAttachment.texture = shadow; shadowPass.depthAttachment.loadAction = .clear; shadowPass.depthAttachment.storeAction = .store; shadowPass.depthAttachment.clearDepth = 1
        let s = command.makeRenderCommandEncoder(descriptor:shadowPass)!
        s.setRenderPipelineState(shadowPipeline); s.setDepthStencilState(depthState); s.setCullMode(.none); s.setVertexBuffer(vertices,offset:0,index:0); s.setVertexBytes(&uniform,length:MemoryLayout<PaperUniform>.stride,index:1); s.setFragmentTexture(texture,index:0); s.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:mesh.count); s.endEncoding()
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = color; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store; pass.colorAttachments[0].clearColor = (transparent ? MTLClearColor(red:0,green:0,blue:0,alpha:0) : MTLClearColor(red:0.13,green:0.15,blue:0.19,alpha:1))
        pass.depthAttachment.texture=depth; pass.depthAttachment.loadAction = .clear; pass.depthAttachment.storeAction = .dontCare; pass.depthAttachment.clearDepth = 1
        let e = command.makeRenderCommandEncoder(descriptor:pass)!
        e.setRenderPipelineState(pipeline); e.setDepthStencilState(depthState); e.setCullMode(.none); e.setVertexBuffer(vertices,offset:0,index:0); e.setVertexBytes(&uniform,length:MemoryLayout<PaperUniform>.stride,index:1); e.setFragmentTexture(texture,index:0); e.setFragmentTexture(shadow,index:1); e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:mesh.count); e.endEncoding()
        let blit = command.makeBlitCommandEncoder()!
        blit.copy(from:color,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),to:readback,destinationOffset:0,destinationBytesPerRow:width*4,destinationBytesPerImage:width*height*4); blit.endEncoding()
        command.commit(); command.waitUntilCompleted(); if let error = command.error { throw error }
        let pixels = Data(bytes:readback.contents(),count:width*height*4)
        let image = CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:CGDataProvider(data:pixels as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
        if milliseconds.count < 300 { milliseconds.append((CACurrentMediaTime()-tick)*1000) }; return image
    }
}

func paperMeshPrototypeQA() {
    precondition(Bundle.main.bundleIdentifier?.hasSuffix(".qa") == true)
    _ = NSApplication.shared
    let root = URL(fileURLWithPath:ProcessInfo.processInfo.environment["CLIPNEST_QA_DIR"] ?? NSTemporaryDirectory()+"clipnest-mesh-prototype")
    try! FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    do {
        let gpu = try PaperGPU(), seeds: [UInt64] = [7,42,91]
        let templates = seeds.map(PaperTemplate.init(seed:))
        let geometryChecks = templates.map(meshValidation)
        print("Mesh diagnostic intersections=\(geometryChecks.map { $0.intersections }), max face-edge strain=\(geometryChecks.map { $0.strain })")
        let gif = root.appendingPathComponent("ClipNest-PaperMesh-GPU-Synthetic-0.5s.gif")
        let destination = CGImageDestinationCreateWithURL(gif as CFURL,UTType.gif.identifier as CFString,73,nil)!
        CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        func progress(_ time: Float) -> Float {
            if time < 0.25 { return 0 }
            if time < 0.75 { return (time-0.25)/0.5 }
            if time < 1 { return 1 }
            if time < 1.2 { return 1-(time-1)/0.5 }
            if time < 1.4 { return 0.6+(time-1.2)/0.5 }
            if time < 1.75 { return 1 }
            return max(0,1-(time-1.75)/0.5)
        }
        for frame in 0...72 {
            let p = progress(Float(frame)/30)
            let canvas = NSImage(size:NSSize(width:1536,height:270)); canvas.lockFocus()
            NSColor(srgbRed:0.13,green:0.15,blue:0.19,alpha:1).setFill(); NSRect(origin:.zero,size:canvas.size).fill()
            for (i,template) in templates.enumerated() {
                let image = try gpu.render(template,progress:p)
                NSImage(cgImage:image,size:NSSize(width:512,height:240)).draw(in:NSRect(x:i*512,y:0,width:512,height:240))
                ("Seed "+String(seeds[i])+" · Native GPU · Synthetic" as NSString).draw(in:NSRect(x:i*512+18,y:244,width:480,height:20),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.white])
                if i == 1 && [11,15,19,23].contains(frame) {
                    let url=root.appendingPathComponent("ClipNest-Mesh-Frame-\(frame).png")
                    let single=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
                    CGImageDestinationAddImage(single,image,nil); precondition(CGImageDestinationFinalize(single))
                }
            }
            canvas.unlockFocus(); let bitmap=NSBitmapImageRep(data:canvas.tiffRepresentation!)!
            CGImageDestinationAddImage(destination,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30,kCGImagePropertyGIFUnclampedDelayTime:1.0/30]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
        precondition(CGImageSourceGetCount(CGImageSourceCreateWithURL(gif as CFURL,nil)!)==73)
        let report: [String:Any] = ["nativeGPU":true,"synthetic":true,"durationSeconds":0.5,"triangles":128,"seeds":seeds,"frames":73,"readbackFrames":gpu.milliseconds.count,"averageReadbackMilliseconds":gpu.milliseconds.reduce(0,+)/Double(gpu.milliseconds.count),"maximumReadbackMilliseconds":gpu.milliseconds.max()!,"integratedIntoApp":false,"sampledSelfIntersections":geometryChecks.map { $0.intersections },"maximumFaceEdgeStrain":geometryChecks.map { $0.strain },"sharedVertices":85,"topologyFixed":true]
        try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("mesh-report.json"))
        print("PASS: native Metal color+depth+shadow GPU render/readback; 73-frame synthetic 0.5s three-seed fold/exit/reenter GIF. Prototype only; self-intersection and UI integration not yet approved.")
    } catch { fatalError("Native mesh prototype failed: \(error)") }
}


func paperMeshSeedQA() {
    precondition(Bundle.main.bundleIdentifier?.hasSuffix(".qa") == true)
    var failures = 0
    for seed in DragPreview.allowedSeeds {
        let result = meshValidation(PaperTemplate(seed: seed))
        FileHandle.standardOutput.write(Data("Trial seed \(seed): \(result.intersections) sampled intersections, edge strain \(result.strain)\n".utf8))
        if result.intersections != 0 { failures += 1 }
    }
    precondition(failures == 0, "Runtime seed pool has sampled crossings")
    FileHandle.standardOutput.write(Data("PASS: runtime seed pool screened at 81 samples; coplanar overlap is not covered\n".utf8))
}
