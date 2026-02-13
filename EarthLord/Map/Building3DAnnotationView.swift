//
//  Building3DAnnotationView.swift
//  EarthLord
//
//  3D SceneKit building annotation view — tactical hologram style
//  Replaces the 2D hexagon marker with isometric 3D models
//

import UIKit
import MapKit
import SceneKit

final class Building3DAnnotationView: MKAnnotationView {

    static let reuseID = "Building3DAnnotation"

    // MARK: - Properties

    private var scnView: SCNView!
    private var shadowLayer: CALayer!
    private var buildingNode: SCNNode?

    /// Cached state to skip redundant configures on reuse
    private var lastTemplateId: String?
    private var lastIsActive: Bool?

    // MARK: - Init

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupSceneView()
        setupShadow()
        canShowCallout = true
        frame = CGRect(x: 0, y: 0, width: 64, height: 80)
        centerOffset = CGPoint(x: 0, y: -40)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Scene Setup (one-time)

    private func setupSceneView() {
        let scene = SCNScene()

        // Orthographic camera — classic isometric angle
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.usesOrthographicProjection = true
        cameraNode.camera!.orthographicScale = 1.2
        cameraNode.position = SCNVector3(0, 2.0, 3.0)
        cameraNode.look(at: SCNVector3(0, 0.3, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Ambient light — soft fill
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor.white
        ambientLight.light!.intensity = 300
        scene.rootNode.addChildNode(ambientLight)

        // Directional light — main illumination
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = UIColor.white
        directionalLight.light!.intensity = 800
        directionalLight.light!.castsShadow = false
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 6, 0)
        scene.rootNode.addChildNode(directionalLight)

        // SCNView
        scnView = SCNView(frame: CGRect(x: 0, y: 0, width: 64, height: 80))
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.isUserInteractionEnabled = false
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 0
        scnView.rendersContinuously = false
        addSubview(scnView)
    }

    private func setupShadow() {
        shadowLayer = CALayer()
        shadowLayer.frame = CGRect(x: 16, y: 68, width: 32, height: 8)
        shadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.3).cgColor
        shadowLayer.cornerRadius = 4
        layer.insertSublayer(shadowLayer, at: 0)
    }

    // MARK: - Configure

    func configure(with buildingAnnotation: BuildingAnnotation) {
        let building = buildingAnnotation.building
        let templateId = building.templateId
        let isActive = building.status == .active

        // Early return if nothing changed
        if templateId == lastTemplateId && isActive == lastIsActive {
            return
        }
        lastTemplateId = templateId
        lastIsActive = isActive

        // Remove old building node
        buildingNode?.removeFromParentNode()
        buildingNode?.removeAllActions()
        buildingNode = nil

        // Create new building node
        let node = SCNNode()
        let geometry = createGeometry(for: templateId)
        let category = buildingAnnotation.template?.category
        geometry.firstMaterial = createHologramMaterial(
            for: templateId, category: category, isActive: isActive
        )
        node.geometry = geometry

        // Special case: solar_array has a child disc
        if templateId == "solar_array" {
            let disc = SCNCylinder(radius: 0.35, height: 0.05)
            disc.firstMaterial = createHologramMaterial(
                for: templateId, category: category, isActive: isActive
            )
            let discNode = SCNNode(geometry: disc)
            discNode.position = SCNVector3(0, 0.35, 0)
            node.addChildNode(discNode)

            if isActive {
                addRotationAnimation(to: discNode)
            }
        }

        scnView.scene?.rootNode.addChildNode(node)
        buildingNode = node

        // Animations for active buildings
        if isActive {
            addHoverAnimation(to: node)
            if templateId == "campfire" {
                addFlickerAnimation(to: node)
            }
            scnView.preferredFramesPerSecond = 30
            scnView.rendersContinuously = true
        } else {
            scnView.preferredFramesPerSecond = 1
            scnView.rendersContinuously = false
            // Render one frame then stop
            scnView.setNeedsDisplay()
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        buildingNode?.removeAllActions()
        buildingNode?.removeFromParentNode()
        buildingNode = nil
        lastTemplateId = nil
        lastIsActive = nil
        scnView.rendersContinuously = false
        scnView.preferredFramesPerSecond = 0
    }

    // MARK: - Geometry

    private func createGeometry(for templateId: String) -> SCNGeometry {
        switch templateId {
        case "campfire":
            return SCNBox(width: 0.6, height: 0.4, length: 0.6, chamferRadius: 0.05)
        case "shelter_frame":
            return SCNPyramid(width: 0.7, height: 0.8, length: 0.7)
        case "small_cache":
            return SCNBox(width: 0.7, height: 0.35, length: 0.5, chamferRadius: 0.03)
        case "workbench":
            return SCNBox(width: 0.8, height: 0.5, length: 0.6, chamferRadius: 0.02)
        case "solar_array":
            // Pedestal cylinder — disc is added as child node in configure()
            return SCNCylinder(radius: 0.15, height: 0.6)
        default:
            return SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0.05)
        }
    }

    // MARK: - Hologram Material

    private func createHologramMaterial(
        for templateId: String,
        category: BuildingCategory?,
        isActive: Bool
    ) -> SCNMaterial {
        let (baseColor, emissionColor) = hologramColors(for: templateId, category: category)

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.blendMode = .add
        material.isDoubleSided = true
        material.diffuse.contents = baseColor.withAlphaComponent(0.3)
        material.emission.contents = emissionColor.withAlphaComponent(0.7)
        material.metalness.contents = 0.2
        material.roughness.contents = 0.8
        material.transparency = isActive ? 0.6 : 0.3
        return material
    }

    private func hologramColors(
        for templateId: String,
        category: BuildingCategory?
    ) -> (base: UIColor, emission: UIColor) {
        switch templateId {
        case "campfire":
            return (
                UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1.0),
                UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
            )
        case "shelter_frame":
            return (
                UIColor(red: 0.6, green: 0.65, blue: 0.7, alpha: 1.0),
                UIColor(red: 0.5, green: 0.6, blue: 0.7, alpha: 1.0)
            )
        case "small_cache":
            return (
                UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0),
                UIColor(red: 0.7, green: 0.45, blue: 0.2, alpha: 1.0)
            )
        case "workbench":
            return (
                UIColor(red: 0.4, green: 0.3, blue: 0.85, alpha: 1.0),
                UIColor(red: 0.5, green: 0.35, blue: 0.9, alpha: 1.0)
            )
        case "solar_array":
            return (
                UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0)
            )
        default:
            return (
                UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
                UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
            )
        }
    }

    // MARK: - Animations

    /// Hover bob — all active buildings float up and down
    private func addHoverAnimation(to node: SCNNode) {
        let moveUp = SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 1.2)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 1.2)
        moveDown.timingMode = .easeInEaseOut
        let hover = SCNAction.sequence([moveUp, moveDown])
        node.runAction(.repeatForever(hover), forKey: "hover")
    }

    /// Flicker — campfire emission pulse via sin composition
    private func addFlickerAnimation(to node: SCNNode) {
        let flicker = SCNAction.customAction(duration: 2.0) { actionNode, elapsedTime in
            let t = Float(elapsedTime)
            let intensity = 0.5 + 0.3 * (sin(t * 12) + sin(t * 7.3)) / 2.0
            let clamped = max(0.2, min(1.0, intensity))
            actionNode.geometry?.firstMaterial?.emission.intensity = CGFloat(clamped)
        }
        node.runAction(.repeatForever(flicker), forKey: "flicker")
    }

    /// Rotation — solar_array disc spins
    private func addRotationAnimation(to node: SCNNode) {
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 6.0)
        node.runAction(.repeatForever(rotate), forKey: "rotate")
    }
}
