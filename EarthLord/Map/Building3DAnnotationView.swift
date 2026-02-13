//
//  Building3DAnnotationView.swift
//  EarthLord
//
//  3D SceneKit building annotation — Pocket Build style miniatures
//  Each building is a composite of multiple SceneKit primitives
//  assembled to look like recognizable structures on the map.
//

import UIKit
import MapKit
import SceneKit

final class Building3DAnnotationView: MKAnnotationView {

    static let reuseID = "Building3DAnnotation"

    // MARK: - Properties

    private var scnView: SCNView!
    private var buildingNode: SCNNode?
    private var lastTemplateId: String?
    private var lastIsActive: Bool?
    private var progressLabel: UILabel?
    private var displayLink: CADisplayLink?
    private var currentBuilding: PlayerBuilding?

    // MARK: - Init

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let size: CGFloat = 90
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        backgroundColor = .clear
        centerOffset = CGPoint(x: 0, y: -size / 2)
        canShowCallout = true
        setupSceneView()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Scene (one-time, camera + lights persist across reuses)

    private func setupSceneView() {
        let scene = SCNScene()

        // Camera — perspective, close isometric angle
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 35
        camera.zNear = 0.1
        camera.zFar = 20
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(1.5, 1.8, 2.2)
        cameraNode.look(at: SCNVector3(0, 0.25, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Key light — warm directional from upper-left
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light!.type = .directional
        keyLight.light!.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.light!.intensity = 1000
        keyLight.eulerAngles = SCNVector3(-Float.pi / 3, -Float.pi / 6, 0)
        scene.rootNode.addChildNode(keyLight)

        // Fill light — soft ambient
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light!.type = .ambient
        fillLight.light!.color = UIColor(white: 0.45, alpha: 1.0)
        fillLight.light!.intensity = 400
        scene.rootNode.addChildNode(fillLight)

        // Rim light — from behind for edge highlights
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light!.type = .directional
        rimLight.light!.color = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
        rimLight.light!.intensity = 500
        rimLight.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi, 0)
        scene.rootNode.addChildNode(rimLight)

        scnView = SCNView(frame: bounds)
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.allowsCameraControl = false
        scnView.isUserInteractionEnabled = false
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 30
        scnView.rendersContinuously = true
        addSubview(scnView)
    }

    // MARK: - Configure

    func configure(with buildingAnnotation: BuildingAnnotation) {
        let building = buildingAnnotation.building
        let templateId = building.templateId
        let isActive = building.status == .active

        if templateId == lastTemplateId && isActive == lastIsActive { return }
        lastTemplateId = templateId
        lastIsActive = isActive

        // Clear old
        buildingNode?.removeAllActions()
        buildingNode?.enumerateChildNodes { child, _ in child.removeAllActions() }
        buildingNode?.removeFromParentNode()
        buildingNode = nil

        // Build new composite structure
        let node = createBuilding(templateId: templateId, isActive: isActive)

        // Ground shadow
        let shadowGeo = SCNCylinder(radius: 0.5, height: 0.005)
        let shadowMat = SCNMaterial()
        shadowMat.diffuse.contents = UIColor.black.withAlphaComponent(0.4)
        shadowMat.lightingModel = .constant
        shadowGeo.materials = [shadowMat]
        let shadowNode = SCNNode(geometry: shadowGeo)
        shadowNode.position = SCNVector3(0, 0.002, 0)
        node.addChildNode(shadowNode)

        scnView.scene?.rootNode.addChildNode(node)
        buildingNode = node

        if isActive {
            removeProgressLabel()
            addHoverAnimation(to: node)
            scnView.preferredFramesPerSecond = 30
            scnView.rendersContinuously = true
        } else {
            addScaffolding(to: node, height: scaffoldHeight(for: templateId))
            setupProgressLabel(building: building)
            scnView.preferredFramesPerSecond = 30
            scnView.rendersContinuously = true
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        buildingNode?.removeAllActions()
        buildingNode?.enumerateChildNodes { child, _ in child.removeAllActions() }
        buildingNode?.removeFromParentNode()
        buildingNode = nil
        lastTemplateId = nil
        lastIsActive = nil
        removeProgressLabel()
        scnView.rendersContinuously = false
        scnView.preferredFramesPerSecond = 0
    }

    // MARK: - Composite Building Factories

    private func createBuilding(templateId: String, isActive: Bool) -> SCNNode {
        switch templateId {
        case "campfire":     return buildCampfire(isActive: isActive)
        case "shelter_frame": return buildShelter(isActive: isActive)
        case "small_cache":  return buildCache(isActive: isActive)
        case "workbench":    return buildWorkbench(isActive: isActive)
        case "solar_array":  return buildSolarArray(isActive: isActive)
        default:             return buildDefault(isActive: isActive)
        }
    }

    // --- Campfire: flat crossed logs + layered flames (red→orange→yellow) + rocks ---
    private func buildCampfire(isActive: Bool) -> SCNNode {
        let root = SCNNode()
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        // Dark brown log material
        let darkLogMat = makeMat(
            diffuse: UIColor(red: 0.32, green: 0.18, blue: 0.08, alpha: alpha),
            emission: UIColor(red: 0.15, green: 0.06, blue: 0.0, alpha: 0.15)
        )
        // Lighter reddish-brown log material
        let lightLogMat = makeMat(
            diffuse: UIColor(red: 0.5, green: 0.25, blue: 0.1, alpha: alpha),
            emission: UIColor(red: 0.2, green: 0.08, blue: 0.0, alpha: 0.15)
        )

        // 4 flat logs in star/cross pattern — tips raised to form a peak
        let logRadius: CGFloat = 0.03
        let logLength: CGFloat = 0.45
        let logAngles: [Float] = [0, Float.pi / 2, Float.pi / 4, -Float.pi / 4]
        let logMats = [darkLogMat, lightLogMat, darkLogMat, lightLogMat]
        for (i, yAngle) in logAngles.enumerated() {
            let geo = SCNCylinder(radius: logRadius, height: logLength)
            geo.materials = [logMats[i]]
            let log = SCNNode(geometry: geo)
            // Lay flat (Z rotation 90°) but tilt ends up ~15° so tips converge at center
            log.eulerAngles = SCNVector3(0, yAngle, Float.pi / 2)
            log.position = SCNVector3(0, 0.06, 0)
            root.addChildNode(log)
        }

        // Small rocks around the base
        let rockMat = makeMat(
            diffuse: UIColor(red: 0.38, green: 0.35, blue: 0.3, alpha: alpha),
            emission: UIColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 0.1)
        )
        let rockPositions: [(Float, Float)] = [
            (-0.2, 0.12), (0.2, 0.1), (0.0, -0.22),
            (-0.15, -0.15), (0.18, -0.12), (-0.22, -0.02)
        ]
        for (rx, rz) in rockPositions {
            let size = Float.random(in: 0.03...0.055)
            let geo = SCNSphere(radius: CGFloat(size))
            geo.materials = [rockMat]
            let rock = SCNNode(geometry: geo)
            rock.position = SCNVector3(rx, Float(size) * 0.5, rz)
            rock.scale = SCNVector3(1.0, 0.6, 1.0) // flatten
            root.addChildNode(rock)
        }

        // Glowing embers at base center
        let emberGeo = SCNCylinder(radius: 0.1, height: 0.02)
        let emberMat = makeMat(
            diffuse: UIColor(red: 0.7, green: 0.15, blue: 0.0, alpha: alpha),
            emission: UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1.0)
        )
        emberMat.emission.intensity = isActive ? 1.0 : 0.2
        emberGeo.materials = [emberMat]
        let embers = SCNNode(geometry: emberGeo)
        embers.position = SCNVector3(0, 0.05, 0)
        root.addChildNode(embers)

        // === Layered flames: wide red base → orange middle → yellow tip ===
        // Each flame is a cone; layered from outside-in, bottom-to-top
        struct FlameSpec {
            let h: CGFloat; let r: CGFloat; let x: Float; let z: Float
            let tilt: Float; let diffuse: UIColor; let emission: UIColor
        }
        let flames: [FlameSpec] = [
            // Red base flames — wide, short
            FlameSpec(h: 0.18, r: 0.1, x: -0.04, z: 0.02, tilt: 0.12,
                      diffuse: UIColor(red: 0.9, green: 0.2, blue: 0.0, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.15, blue: 0.0, alpha: 1)),
            FlameSpec(h: 0.16, r: 0.09, x: 0.05, z: -0.03, tilt: -0.1,
                      diffuse: UIColor(red: 0.95, green: 0.25, blue: 0.0, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1)),
            // Orange middle flames — taller, narrower
            FlameSpec(h: 0.28, r: 0.07, x: 0.0, z: 0.0, tilt: 0.0,
                      diffuse: UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)),
            FlameSpec(h: 0.24, r: 0.06, x: -0.03, z: -0.02, tilt: 0.08,
                      diffuse: UIColor(red: 1.0, green: 0.55, blue: 0.05, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1)),
            FlameSpec(h: 0.22, r: 0.055, x: 0.04, z: 0.02, tilt: -0.06,
                      diffuse: UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)),
            // Yellow tip flame — tallest, thinnest
            FlameSpec(h: 0.35, r: 0.04, x: 0.0, z: 0.0, tilt: 0.0,
                      diffuse: UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1)),
            FlameSpec(h: 0.25, r: 0.035, x: 0.03, z: -0.01, tilt: -0.15,
                      diffuse: UIColor(red: 1.0, green: 0.9, blue: 0.35, alpha: alpha),
                      emission: UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)),
        ]

        var flameNodes: [SCNNode] = []
        for f in flames {
            let geo = SCNCone(topRadius: 0, bottomRadius: f.r, height: f.h)
            let mat = makeMat(diffuse: f.diffuse, emission: f.emission)
            mat.emission.intensity = isActive ? 1.6 : 0.3
            mat.transparency = isActive ? 0.9 : 0.5
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(f.x, 0.07 + Float(f.h / 2), f.z)
            node.eulerAngles = SCNVector3(f.tilt, 0, -f.tilt * 0.4)
            root.addChildNode(node)
            flameNodes.append(node)
        }

        if isActive {
            // Point light
            let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light!.type = .omni
            lightNode.light!.color = UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
            lightNode.light!.intensity = 500
            lightNode.light!.attenuationStartDistance = 0
            lightNode.light!.attenuationEndDistance = 3.0
            lightNode.position = SCNVector3(0, 0.25, 0)
            root.addChildNode(lightNode)

            for (i, flame) in flameNodes.enumerated() {
                addFlameFlicker(to: flame, phase: Float(i) * 0.9)
            }
            addEmberPulse(to: embers)
        }

        return root
    }

    // --- Shelter: box walls + pyramid roof + door ---
    private func buildShelter(isActive: Bool) -> SCNNode {
        let root = SCNNode()
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        // Wall base
        let wallGeo = SCNBox(width: 0.55, height: 0.4, length: 0.5, chamferRadius: 0.01)
        wallGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.55, green: 0.52, blue: 0.48, alpha: alpha),
            emission: UIColor(red: 0.25, green: 0.3, blue: 0.35, alpha: 0.4)
        )]
        let walls = SCNNode(geometry: wallGeo)
        walls.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(walls)

        // Roof — pyramid
        let roofGeo = SCNPyramid(width: 0.65, height: 0.35, length: 0.6)
        roofGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.5, green: 0.3, blue: 0.15, alpha: alpha),
            emission: UIColor(red: 0.3, green: 0.18, blue: 0.08, alpha: 0.3)
        )]
        let roof = SCNNode(geometry: roofGeo)
        roof.position = SCNVector3(0, 0.4, 0)
        root.addChildNode(roof)

        // Door — small dark box on front face
        let doorGeo = SCNBox(width: 0.12, height: 0.2, length: 0.02, chamferRadius: 0)
        doorGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: alpha),
            emission: UIColor(red: 0.1, green: 0.08, blue: 0.05, alpha: 0.2)
        )]
        let door = SCNNode(geometry: doorGeo)
        door.position = SCNVector3(0, 0.1, 0.26)
        root.addChildNode(door)

        // Window glow (active only)
        if isActive {
            let windowGeo = SCNBox(width: 0.1, height: 0.08, length: 0.02, chamferRadius: 0)
            let winMat = makeMat(
                diffuse: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0),
                emission: UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
            )
            winMat.emission.intensity = 1.2
            windowGeo.materials = [winMat]
            let window = SCNNode(geometry: windowGeo)
            window.position = SCNVector3(0.15, 0.25, 0.26)
            root.addChildNode(window)
        }

        return root
    }

    // --- Cache: wooden crate with lid + straps ---
    private func buildCache(isActive: Bool) -> SCNNode {
        let root = SCNNode()
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        // Crate body
        let crateGeo = SCNBox(width: 0.5, height: 0.3, length: 0.4, chamferRadius: 0.02)
        crateGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.6, green: 0.42, blue: 0.2, alpha: alpha),
            emission: UIColor(red: 0.35, green: 0.22, blue: 0.08, alpha: 0.3)
        )]
        let crate = SCNNode(geometry: crateGeo)
        crate.position = SCNVector3(0, 0.15, 0)
        root.addChildNode(crate)

        // Lid — slightly wider, thin
        let lidGeo = SCNBox(width: 0.54, height: 0.04, length: 0.44, chamferRadius: 0.01)
        lidGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.55, green: 0.38, blue: 0.17, alpha: alpha),
            emission: UIColor(red: 0.3, green: 0.2, blue: 0.06, alpha: 0.25)
        )]
        let lid = SCNNode(geometry: lidGeo)
        lid.position = SCNVector3(0, 0.32, 0)
        root.addChildNode(lid)

        // Metal straps (2 horizontal bands)
        let strapMat = makeMat(
            diffuse: UIColor(red: 0.35, green: 0.35, blue: 0.32, alpha: alpha),
            emission: UIColor(red: 0.2, green: 0.2, blue: 0.18, alpha: 0.2)
        )
        for z: Float in [-0.1, 0.1] {
            let strapGeo = SCNBox(width: 0.52, height: 0.03, length: 0.04, chamferRadius: 0)
            strapGeo.materials = [strapMat]
            let strap = SCNNode(geometry: strapGeo)
            strap.position = SCNVector3(0, 0.15, z)
            root.addChildNode(strap)
        }

        // Lock (small metallic cube on front)
        let lockGeo = SCNBox(width: 0.05, height: 0.06, length: 0.05, chamferRadius: 0.01)
        let lockMat = makeMat(
            diffuse: UIColor(red: 0.7, green: 0.65, blue: 0.3, alpha: alpha),
            emission: UIColor(red: 0.5, green: 0.45, blue: 0.15, alpha: 0.3)
        )
        lockGeo.materials = [lockMat]
        let lock = SCNNode(geometry: lockGeo)
        lock.position = SCNVector3(0, 0.28, 0.22)
        root.addChildNode(lock)

        return root
    }

    // --- Workbench: table top + 4 legs + tools ---
    private func buildWorkbench(isActive: Bool) -> SCNNode {
        let root = SCNNode()
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        // Table top
        let topGeo = SCNBox(width: 0.6, height: 0.05, length: 0.4, chamferRadius: 0.01)
        topGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.45, green: 0.32, blue: 0.18, alpha: alpha),
            emission: UIColor(red: 0.25, green: 0.15, blue: 0.06, alpha: 0.3)
        )]
        let top = SCNNode(geometry: topGeo)
        top.position = SCNVector3(0, 0.35, 0)
        root.addChildNode(top)

        // 4 Legs
        let legMat = makeMat(
            diffuse: UIColor(red: 0.38, green: 0.25, blue: 0.13, alpha: alpha),
            emission: UIColor(red: 0.15, green: 0.1, blue: 0.04, alpha: 0.2)
        )
        let legPositions: [(Float, Float)] = [(-0.24, -0.15), (0.24, -0.15), (-0.24, 0.15), (0.24, 0.15)]
        for (x, z) in legPositions {
            let legGeo = SCNBox(width: 0.05, height: 0.32, length: 0.05, chamferRadius: 0)
            legGeo.materials = [legMat]
            let leg = SCNNode(geometry: legGeo)
            leg.position = SCNVector3(x, 0.16, z)
            root.addChildNode(leg)
        }

        // Anvil on table (small metallic block)
        let anvilGeo = SCNBox(width: 0.12, height: 0.08, length: 0.08, chamferRadius: 0.01)
        anvilGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: alpha),
            emission: UIColor(red: 0.4, green: 0.35, blue: 0.8, alpha: isActive ? 0.6 : 0.1)
        )]
        let anvil = SCNNode(geometry: anvilGeo)
        anvil.position = SCNVector3(-0.12, 0.415, 0)
        root.addChildNode(anvil)

        // Hammer (cylinder handle + small box head)
        let handleGeo = SCNCylinder(radius: 0.015, height: 0.18)
        handleGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.5, green: 0.35, blue: 0.15, alpha: alpha),
            emission: UIColor(red: 0.2, green: 0.12, blue: 0.05, alpha: 0.2)
        )]
        let handle = SCNNode(geometry: handleGeo)
        handle.position = SCNVector3(0.12, 0.47, 0)
        handle.eulerAngles = SCNVector3(0, 0, Float.pi / 5)
        root.addChildNode(handle)

        let headGeo = SCNBox(width: 0.06, height: 0.04, length: 0.04, chamferRadius: 0.005)
        headGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.4, green: 0.4, blue: 0.42, alpha: alpha),
            emission: UIColor(red: 0.3, green: 0.3, blue: 0.7, alpha: isActive ? 0.5 : 0.1)
        )]
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0.05, 0.55, 0)
        root.addChildNode(head)

        return root
    }

    // --- Solar Array: pole + tilted panel + base platform ---
    private func buildSolarArray(isActive: Bool) -> SCNNode {
        let root = SCNNode()
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        // Base platform
        let baseGeo = SCNCylinder(radius: 0.2, height: 0.04)
        baseGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: alpha),
            emission: UIColor(red: 0.15, green: 0.2, blue: 0.3, alpha: 0.3)
        )]
        let base = SCNNode(geometry: baseGeo)
        base.position = SCNVector3(0, 0.02, 0)
        root.addChildNode(base)

        // Pole
        let poleGeo = SCNCylinder(radius: 0.03, height: 0.45)
        poleGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.4, green: 0.42, blue: 0.45, alpha: alpha),
            emission: UIColor(red: 0.2, green: 0.25, blue: 0.35, alpha: 0.3)
        )]
        let pole = SCNNode(geometry: poleGeo)
        pole.position = SCNVector3(0, 0.265, 0)
        root.addChildNode(pole)

        // Solar panel — flat box tilted 30°
        let panelGeo = SCNBox(width: 0.55, height: 0.02, length: 0.45, chamferRadius: 0.01)
        let panelMat = makeMat(
            diffuse: UIColor(red: 0.15, green: 0.35, blue: 0.7, alpha: alpha),
            emission: UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: isActive ? 0.8 : 0.2)
        )
        panelMat.emission.intensity = isActive ? 1.0 : 0.3
        panelMat.specular.contents = UIColor.white
        panelMat.shininess = 0.9
        panelGeo.materials = [panelMat]
        let panel = SCNNode(geometry: panelGeo)
        panel.position = SCNVector3(0, 0.5, 0)
        panel.eulerAngles = SCNVector3(-Float.pi / 6, 0, 0)
        root.addChildNode(panel)

        // Grid lines on panel (thin dark strips)
        let gridMat = makeMat(
            diffuse: UIColor(red: 0.08, green: 0.2, blue: 0.45, alpha: alpha),
            emission: UIColor(red: 0.05, green: 0.15, blue: 0.35, alpha: 0.2)
        )
        for x: Float in [-0.15, 0, 0.15] {
            let gridGeo = SCNBox(width: 0.01, height: 0.025, length: 0.42, chamferRadius: 0)
            gridGeo.materials = [gridMat]
            let grid = SCNNode(geometry: gridGeo)
            grid.position = SCNVector3(x, 0.5, 0)
            grid.eulerAngles = SCNVector3(-Float.pi / 6, 0, 0)
            root.addChildNode(grid)
        }

        if isActive {
            addRotationAnimation(to: panel)
            // Rotate grid lines together
            for child in root.childNodes where child.geometry is SCNBox && child.position.y > 0.48 && child != panel {
                // We'll wrap panel + grids in a parent to rotate together
            }
        }

        return root
    }

    // --- Default: generic cube building ---
    private func buildDefault(isActive: Bool) -> SCNNode {
        let root = SCNNode()
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        let boxGeo = SCNBox(width: 0.45, height: 0.45, length: 0.45, chamferRadius: 0.03)
        boxGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.5, green: 0.5, blue: 0.52, alpha: alpha),
            emission: UIColor(red: 0.3, green: 0.4, blue: 0.35, alpha: 0.3)
        )]
        let box = SCNNode(geometry: boxGeo)
        box.position = SCNVector3(0, 0.225, 0)
        root.addChildNode(box)

        // Small roof
        let roofGeo = SCNPyramid(width: 0.52, height: 0.2, length: 0.52)
        roofGeo.materials = [makeMat(
            diffuse: UIColor(red: 0.4, green: 0.38, blue: 0.36, alpha: alpha),
            emission: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.2)
        )]
        let roof = SCNNode(geometry: roofGeo)
        roof.position = SCNVector3(0, 0.45, 0)
        root.addChildNode(roof)

        return root
    }

    // MARK: - Construction Scaffolding

    private func scaffoldHeight(for templateId: String) -> CGFloat {
        switch templateId {
        case "campfire":      return 0.45
        case "shelter_frame": return 0.75
        case "small_cache":   return 0.36
        case "workbench":     return 0.60
        case "solar_array":   return 0.55
        default:              return 0.65
        }
    }

    private func addScaffolding(to node: SCNNode, height: CGFloat) {
        let scaffoldColor = UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 1.0)
        let scaffoldMat = SCNMaterial()
        scaffoldMat.diffuse.contents = scaffoldColor.withAlphaComponent(0.6)
        scaffoldMat.emission.contents = scaffoldColor
        scaffoldMat.emission.intensity = 0.6
        scaffoldMat.lightingModel = .constant
        scaffoldMat.isDoubleSided = true

        let poleRadius: CGFloat = 0.015
        let spread: Float = 0.35

        // 4 vertical poles at corners
        let corners: [(Float, Float)] = [
            (-spread, -spread), (spread, -spread),
            (-spread, spread), (spread, spread)
        ]
        var poleNodes: [SCNNode] = []
        for (x, z) in corners {
            let poleGeo = SCNCylinder(radius: poleRadius, height: height)
            poleGeo.materials = [scaffoldMat.copy() as! SCNMaterial]
            let pole = SCNNode(geometry: poleGeo)
            pole.position = SCNVector3(x, Float(height / 2), z)
            node.addChildNode(pole)
            poleNodes.append(pole)
        }

        // 2 horizontal cross bars
        let barHeight = Float(height * 0.6)
        let barLength = spread * 2
        let barGeo = SCNCylinder(radius: poleRadius * 0.8, height: CGFloat(barLength))
        barGeo.materials = [scaffoldMat.copy() as! SCNMaterial]

        // Bar along X axis (front)
        let barX = SCNNode(geometry: barGeo)
        barX.position = SCNVector3(0, barHeight, spread)
        barX.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        node.addChildNode(barX)

        // Bar along Z axis (side)
        let barGeoZ = SCNCylinder(radius: poleRadius * 0.8, height: CGFloat(barLength))
        let scaffoldMatZ = SCNMaterial()
        scaffoldMatZ.diffuse.contents = scaffoldColor.withAlphaComponent(0.6)
        scaffoldMatZ.emission.contents = scaffoldColor
        scaffoldMatZ.emission.intensity = 0.6
        scaffoldMatZ.lightingModel = .constant
        scaffoldMatZ.isDoubleSided = true
        barGeoZ.materials = [scaffoldMatZ]
        let barZ = SCNNode(geometry: barGeoZ)
        barZ.position = SCNVector3(spread, barHeight, 0)
        barZ.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        node.addChildNode(barZ)

        // Pulsing emission animation on all scaffold parts
        let allScaffoldNodes = poleNodes + [barX, barZ]
        for scaffoldNode in allScaffoldNodes {
            let pulse = SCNAction.customAction(duration: 1.5) { actionNode, elapsed in
                let t: Float = Float(elapsed) / 1.5
                let sinVal: Float = sin(t * Float.pi * 2.0 - Float.pi / 2.0)
                let intensity: CGFloat = CGFloat(0.3 + 0.7 * (0.5 + 0.5 * sinVal))
                actionNode.geometry?.firstMaterial?.emission.intensity = intensity
            }
            scaffoldNode.runAction(.repeatForever(pulse), forKey: "scaffoldPulse")
        }
    }

    // MARK: - Progress Label

    private func setupProgressLabel(building: PlayerBuilding) {
        currentBuilding = building

        if progressLabel == nil {
            let label = UILabel()
            label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = UIColor.darkGray.withAlphaComponent(0.7)
            label.layer.cornerRadius = 6
            label.clipsToBounds = true
            addSubview(label)
            progressLabel = label
        }

        updateProgressText()
        startProgressTimer()
    }

    private func updateProgressText() {
        guard let building = currentBuilding else { return }
        let remaining = building.formattedRemainingTime
        let text = remaining.isEmpty ? "" : " \(remaining) "
        progressLabel?.text = text
        progressLabel?.sizeToFit()

        if let label = progressLabel {
            let labelWidth = max(label.intrinsicContentSize.width + 12, 40)
            let labelHeight: CGFloat = 18
            label.frame = CGRect(
                x: (bounds.width - labelWidth) / 2,
                y: bounds.height - labelHeight - 2,
                width: labelWidth,
                height: labelHeight
            )
        }
    }

    private func removeProgressLabel() {
        stopProgressTimer()
        progressLabel?.removeFromSuperview()
        progressLabel = nil
        currentBuilding = nil
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let link = CADisplayLink(target: self, selector: #selector(timerTick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 1)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopProgressTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func timerTick() {
        updateProgressText()
    }

    // MARK: - Material Helper

    private func makeMat(diffuse: UIColor, emission: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .phong
        m.diffuse.contents = diffuse
        m.emission.contents = emission
        m.isDoubleSided = true
        m.specular.contents = UIColor(white: 0.3, alpha: 1)
        m.shininess = 0.4
        return m
    }

    // MARK: - Animations

    private func addHoverAnimation(to node: SCNNode) {
        // Random delay so buildings don't all bob in sync
        let delay = SCNAction.wait(duration: Double.random(in: 0...1.5))
        let up = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 1.2)
        up.timingMode = .easeInEaseOut
        let down = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 1.2)
        down.timingMode = .easeInEaseOut
        let hover = SCNAction.repeatForever(.sequence([up, down]))
        node.runAction(.sequence([delay, hover]), forKey: "hover")
    }

    /// Flame tongue flicker — stretches Y + sways X + emission pulse (no uniform scale)
    private func addFlameFlicker(to node: SCNNode, phase: Float) {
        let p = phase
        let flicker = SCNAction.customAction(duration: 3.0) { actionNode, elapsedTime in
            let t: Float = Float(elapsedTime) + p

            let s1: Float = sin(t * 8.5) * 0.5
            let s2: Float = sin(t * 13.7) * 0.3
            let s3: Float = sin(t * 5.1) * 0.2
            let yRaw: Float = 0.9 + 0.3 * (s1 + s2 + s3)
            let yScale: Float = max(0.7, min(1.3, yRaw))

            let xSway: Float = 1.0 + 0.06 * sin(t * 6.3 + p)
            actionNode.scale = SCNVector3(xSway, yScale, xSway)

            let i1: Float = sin(t * 11)
            let i2: Float = sin(t * 7.7)
            let iRaw: Float = 1.2 + 0.8 * (i1 + i2) / 2.0
            let intensity: Float = max(0.8, min(2.2, iRaw))
            actionNode.geometry?.firstMaterial?.emission.intensity = CGFloat(intensity)
        }
        node.runAction(.repeatForever(flicker), forKey: "flameFlicker")
    }

    /// Ember glow pulse — slow red throb
    private func addEmberPulse(to node: SCNNode) {
        let pulse = SCNAction.customAction(duration: 4.0) { actionNode, elapsedTime in
            let t = Float(elapsedTime)
            let v = 0.8 + 0.4 * sin(t * 3.0)
            actionNode.geometry?.firstMaterial?.emission.intensity = CGFloat(v)
        }
        node.runAction(.repeatForever(pulse), forKey: "emberPulse")
    }

    private func addRotationAnimation(to node: SCNNode) {
        let rotate = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 10.0)
        node.runAction(.repeatForever(rotate), forKey: "rotate")
    }
}
