// Responsibility: accepted 128-face original-texture paper fold, 0.5s reversible and visual only.
// Relationship: PanelView owns the fixed 52pt pointer hit region; this view never modifies stored data.
// Development status: local trial, not a full collision/cloth simulation.
import AppKit
import QuartzCore

struct MeshDragPose { var center: NSPoint; var progress: Float }
final class DragPreview: NSView {
    static let allowedSeeds: [UInt64] = [13,17,19,21]
    let text: String
    let originalSize: NSSize
    let seed: UInt64
    private(set) var folded = false
    private(set) var pose: MeshDragPose
    private var start: MeshDragPose
    private var target: MeshDragPose
    private var startedAt: TimeInterval = 0, duration: TimeInterval = 0
    private var timer: Timer?
    private let clock: () -> TimeInterval
    private let template: PaperTemplate
    private let original: CGImage
    private var rendered: CGImage?
    private let renderer: PaperGPU?
    private var lastProgress: Float = -1
    var isAnimating: Bool { timer != nil }
    init(title: String, frame: NSRect, seed: UInt64? = nil, clock: (() -> TimeInterval)? = nil, usesMesh: Bool = true, appearance: NSAppearance? = nil) {
        text=title;originalSize=frame.size
        let selection=seed.map { Self.allowedSeeds.contains($0) ? $0 : Self.allowedSeeds[Int($0 % UInt64(Self.allowedSeeds.count))] } ?? Self.allowedSeeds.randomElement()!
        self.seed=selection;template=PaperTemplate(seed:selection)
        let initial=MeshDragPose(center:NSPoint(x:frame.midX,y:frame.midY),progress:0)
        pose=initial;start=initial;target=initial
        self.clock=clock ?? { CACurrentMediaTime() }
        let width=max(2,Int(frame.width*2)),height=max(2,Int(frame.height*2))
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
        NSGraphicsContext.current?.cgContext.scaleBy(x:2,y:2)
        let row=SnippetRow(title:title,target:nil,action:nil);row.isPinned=true;row.frame=NSRect(origin:.zero,size:frame.size)
        (appearance ?? NSApp.effectiveAppearance).performAsCurrentDrawingAppearance { row.draw(row.bounds) }
        NSGraphicsContext.restoreGraphicsState();original=bitmap.cgImage!
        renderer=usesMesh ? PaperGPU.shared : nil
        super.init(frame:frame);wantsLayer=true;setAccessibilityElement(false)
        shadow=NSShadow();shadow?.shadowColor=NSColor.black.withAlphaComponent(0.16);shadow?.shadowBlurRadius=9;shadow?.shadowOffset=NSSize(width:0,height:-3)
        renderer?.setOriginal(original)
    }
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    deinit { timer?.invalidate() }
    override func draw(_ rect:NSRect) {
        NSImage(cgImage:rendered ?? original,size:bounds.size).draw(in:bounds)
    }
    func advance() {
        let fraction=duration==0 ? 1 : min(1,max(0,(clock()-startedAt)/duration))
        let eased=CGFloat(fraction*fraction*(3-2*fraction))
        pose=MeshDragPose(center:NSPoint(x:start.center.x+(target.center.x-start.center.x)*eased,y:start.center.y+(target.center.y-start.center.y)*eased),progress:start.progress+(target.progress-start.progress)*Float(eased))
        var size=originalSize
        if pose.progress>0,let renderer {
            let (mesh,points)=template.geometry(progress:pose.progress,width:Float(originalSize.width),height:Float(originalSize.height))
            if folded,let parent=superview {
                let minX=points.map { $0.x }.min()!,maxX=points.map { $0.x }.max()!
                let half=CGFloat(maxX-minX)/2+10
                if parent.bounds.width>half*2 { pose.center.x=min(parent.bounds.maxX-half,max(parent.bounds.minX+half,pose.center.x)) }
            }
            if abs(pose.progress-lastProgress)>0.00001 { rendered=try? renderer.render(mesh:mesh);lastProgress=pose.progress }
            size=NSSize(width:512,height:240)
        } else { rendered=nil;lastProgress = -1 }
        frame=NSRect(x:pose.center.x-size.width/2,y:pose.center.y-size.height/2,width:size.width,height:size.height);needsDisplay=true
        if fraction>=1 { timer?.invalidate();timer=nil;duration=0 }
    }
    func stopMotion(){advance();timer?.invalidate();timer=nil;duration=0;start=pose;target=pose}
    func follow(pointerFrame:NSRect,trashFrame:NSRect,inside:Bool,reduceMotion:Bool,animated:Bool=true) {
        advance();let changed=folded != inside;folded=inside
        let point=NSPoint(x:pointerFrame.midX,y:pointerFrame.midY)
        let staticFeedback=reduceMotion || renderer==nil
        if !changed && inside && !staticFeedback { return }
        if changed {
            start=pose;target=MeshDragPose(center:inside && !staticFeedback ? NSPoint(x:trashFrame.midX,y:trashFrame.midY) : point,progress:inside && !staticFeedback ? 1 : 0)
            startedAt=clock();duration=animated && !staticFeedback ? 0.5*Double(abs(target.progress-start.progress)) : 0
        } else { target.center=point }
        if !animated || staticFeedback { duration=0 }
        advance();startTimer()
    }
    func returnTo(_ source:NSRect,reduceMotion:Bool) {
        advance();folded=false;start=pose;target=MeshDragPose(center:NSPoint(x:source.midX,y:source.midY),progress:0)
        startedAt=clock();duration=reduceMotion || renderer==nil ? 0 : max(0.16,0.5*Double(pose.progress))
        advance();startTimer()
    }
    private func startTimer() {
        if duration>0 && timer==nil {
            let next=Timer(timeInterval:1/60,repeats:true){[weak self] _ in self?.advance()}
            timer=next;RunLoop.main.add(next,forMode:.common);RunLoop.main.add(next,forMode:.eventTracking)
        }
    }
}
