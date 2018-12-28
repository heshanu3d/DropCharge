import SpriteKit
import CoreMotion

enum GameStatus: Int {
    case waitingForTap = 0
    case waitingForBomb = 1
    case playing = 2
    case gameOver = 3
}
enum PlayerStatus: Int {
    case idle = 0
    case jump = 1
    case fall = 2
    case lava = 3
    case dead = 4 }
struct PhysicsCategory {
    static let None: UInt32                 = 0
    static let Player: UInt32               = 0b1
    static let PlatformNormal: UInt32       = 0b10
    static let PlatformBreakable: UInt32    = 0b100
    static let CoinNormal: UInt32           = 0b1000
    static let CoinSpecial: UInt32          = 0b10000
    static let Edges: UInt32                = 0b100000
}


class GameScene: SKScene, SKPhysicsContactDelegate{
    var gameState = GameStatus.waitingForTap
    var playerState = PlayerStatus.idle
    let motionManager = CMMotionManager()
    var xAcceleration = CGFloat(0)
    let cameraNode = SKCameraNode()
    var lava: SKSpriteNode!
    
    
    var bgNode: SKNode!
    var fgNode: SKNode!
    var backgroundOverlayTemplate: SKNode!
    var backgroundOverlayHeight: CGFloat!
    var player: SKSpriteNode!
    
    var breakArrow : SKSpriteNode!
    var breakDiagonal : SKSpriteNode!
    var break5Across : SKSpriteNode!
    var coin5Across : SKSpriteNode!
    var coinDiagonal : SKSpriteNode!
    var coinArrow: SKSpriteNode!
    var coinCross: SKSpriteNode!
    var coinS5Across : SKSpriteNode!
    var coinSCross : SKSpriteNode!
    var coinSArrow : SKSpriteNode!
    var coinSDiagonal : SKSpriteNode!
    var platformArrow : SKSpriteNode!
    var platformDiagonal : SKSpriteNode!
    var platform5Across: SKSpriteNode!
    
    var lastOverlayPosition = CGPoint.zero
    var lastOverlayHeight: CGFloat = 0.0
    var levelPositionY: CGFloat = 0.0
    var lastUpdateTimeInterval: TimeInterval = 0
    var deltaTime: TimeInterval = 0
    var lives = 3
    
    
    override func didMove(to view: SKView) {
        setupNodes()
        setupLevel()
        fgNode.childNode(withName: "Ready")!.run(SKAction.scale(to: 1.0, duration: 0.5))
        setupPlayer()
        physicsWorld.contactDelegate = self
        setupCoreMotion()
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .waitingForTap { bombDrop() }
        else if gameState == .gameOver {
            let newScene = GameScene(fileNamed:"GameScene")
            newScene!.scaleMode = .aspectFill
            let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            view?.presentScene(newScene!, transition: reveal)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
        switch other.categoryBitMask {
        case PhysicsCategory.CoinNormal:
            if let coin = other.node as? SKSpriteNode { coin.removeFromParent(); jumpPlayer() }
        case PhysicsCategory.CoinSpecial:
            if let coin = other.node as? SKSpriteNode { coin.removeFromParent(); boostPlayer() }
        case PhysicsCategory.PlatformNormal:
            if let _ = other.node as? SKSpriteNode {
                if player.physicsBody!.velocity.dy < 0 { jumpPlayer() } }
        case PhysicsCategory.PlatformBreakable:
            if let platform = other.node as? SKSpriteNode {
                if player.physicsBody!.velocity.dy < 0 { platform.removeFromParent(); jumpPlayer() } }
        default:
            break
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTimeInterval > 0 {
            deltaTime = currentTime - lastUpdateTimeInterval }
        else {
            deltaTime = 0 }
        lastUpdateTimeInterval = currentTime
        if isPaused { return }
        if gameState == .playing {
            updateCamera()
            updateLevel()
            updatePlayer()
            updateLava(deltaTime)
            updateCollisionLava()
        }
    }
    
    func startGame() {
        fgNode.childNode(withName: "Bomb")!.removeFromParent()
        gameState = .playing
        player.physicsBody!.isDynamic = true
        superBoostPlayer()
    }
    
    func setupNodes() {
        let worldNode = childNode(withName: "World")!
        bgNode = worldNode.childNode(withName: "Background")!
        backgroundOverlayTemplate = bgNode.childNode(withName: "Overlay")!.copy() as! SKNode
        backgroundOverlayHeight = backgroundOverlayTemplate.calculateAccumulatedFrame().height
        print("backgroundOverlayHeight:\(backgroundOverlayHeight)")
        fgNode = worldNode.childNode(withName: "Foreground")!
        player = fgNode.childNode(withName: "Player") as! SKSpriteNode
        fgNode.childNode(withName: "Bomb")?.run(SKAction.hide())
        
        breakArrow = loadForegroundOverlayTemplate("BreakArrow")
        breakDiagonal = loadForegroundOverlayTemplate("BreakDiagonal")
        break5Across = loadForegroundOverlayTemplate("Break5Across")
        
        coinArrow = loadForegroundOverlayTemplate("CoinArrow")
        coinCross = loadForegroundOverlayTemplate("CoinCross")
        coin5Across = loadForegroundOverlayTemplate("Coin5Across")
        coinDiagonal = loadForegroundOverlayTemplate("CoinDiagonal")
        coinS5Across = loadForegroundOverlayTemplate("CoinS5Across")
        coinS5Across = loadForegroundOverlayTemplate("CoinS5Across")
        coinSCross = loadForegroundOverlayTemplate("CoinSCross")
        coinSDiagonal = loadForegroundOverlayTemplate("CoinSDiagonal")
        
        platformArrow = loadForegroundOverlayTemplate("PlatformArrow")
        platformDiagonal = loadForegroundOverlayTemplate("PlatformDiagonal")
        platform5Across = loadForegroundOverlayTemplate("Platform5Across")
        
        addChild(cameraNode)
        camera = cameraNode
        lava = fgNode.childNode(withName: "Lava") as! SKSpriteNode
    }
    
    func setupPlayer() {
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width * 0.3)
        player.physicsBody!.isDynamic = false
        player.physicsBody!.allowsRotation = false
        player.physicsBody!.categoryBitMask = PhysicsCategory.Player
        player.physicsBody!.collisionBitMask = 0
    }
    
    func setupLevel() {
        // Place initial platform
        let initialPlatform = platform5Across.copy() as! SKSpriteNode
        var overlayPosition = player.position
        overlayPosition.y = player.position.y - (player.size.height * 0.5 + initialPlatform.size.height * 0.20)
        initialPlatform.position = overlayPosition
        fgNode.addChild(initialPlatform)
        lastOverlayPosition = overlayPosition
        lastOverlayHeight = initialPlatform.size.height / 2.0
        
        // Create random level
        levelPositionY = bgNode.childNode(withName: "Overlay")! .position.y + backgroundOverlayHeight
        while lastOverlayPosition.y < levelPositionY { addRandomForegroundOverlay() }
    }
    
    func updateCamera() {
        let cameraTarget = convert(player.position, from: fgNode)
        var targetPositionY = cameraTarget.y - (size.height * 0.10)
        
        let lavaPos = convert(lava.position, from: fgNode)
        targetPositionY = max(targetPositionY, lavaPos.y)
        
        let diff = targetPositionY - camera!.position.y
        let cameraLagFactor: CGFloat = 0.2
        let lagDiff = diff * cameraLagFactor
        let newCameraPositionY = camera!.position.y + lagDiff
        camera!.position.y = newCameraPositionY
    }
    
    func updateLava(_ dt: TimeInterval) {
        let bottomOfScreenY = camera!.position.y - (size.height / 2)
        let bottomOfScreenYFg = convert(CGPoint(x: 0, y: bottomOfScreenY), to: fgNode).y
        let lavaVelocityY = CGFloat(120)
        let lavaStep = lavaVelocityY * CGFloat(dt)
        var newLavaPositionY = lava.position.y + lavaStep
        newLavaPositionY = max(newLavaPositionY, bottomOfScreenYFg - 125.0)
        lava.position.y = newLavaPositionY
    }
    
    func updateCollisionLava() {
        if player.position.y < lava.position.y + 90 {
            playerState = .lava
            boostPlayer()
            lives -= 1
            if lives <= 0 {
                gameOver() }
        }
    }
    
    func updateLevel() {
        let cameraPos = camera!.position
        if cameraPos.y > levelPositionY - size.height {
            createBackgroundOverlay()
            while lastOverlayPosition.y < levelPositionY {
                addRandomForegroundOverlay()
            }
        }
    }
    
    func loadForegroundOverlayTemplate(_ fileName: String) -> SKSpriteNode {
            let overlayScene = SKScene(fileNamed: fileName)!
            let overlayTemplate = overlayScene.childNode(withName: "Overlay")
            return overlayTemplate as! SKSpriteNode
    }

    func createForegroundOverlay(_ overlayTemplate:
        SKSpriteNode, flipX: Bool) {
        let foregroundOverlay = overlayTemplate.copy() as! SKSpriteNode
        lastOverlayPosition.y = lastOverlayPosition.y + (lastOverlayHeight * 1.3 + (foregroundOverlay.size.height / 2.0))
        lastOverlayHeight = foregroundOverlay.size.height / 2.0
        foregroundOverlay.position = lastOverlayPosition
        if flipX == true {
            foregroundOverlay.xScale = -1.0
        }
        fgNode.addChild(foregroundOverlay)
    }

    func createBackgroundOverlay() {
        let backgroundOverlay = backgroundOverlayTemplate.copy() as!
        SKNode
        backgroundOverlay.position = CGPoint(x: 0.0,
                                             y: levelPositionY)
        bgNode.addChild(backgroundOverlay)
        levelPositionY += backgroundOverlayHeight
    }
    

    
    func addRandomForegroundOverlay() {
        let overlaySprite: SKSpriteNode!
        let platformPercentage = 60
        var flipH = false
        if Int.random(min: 1, max: 100) <= platformPercentage {
            if Int.random(min: 1, max: 100) <= 75 {
                switch Int.random(min: 1, max: 4) {
                case 1: overlaySprite = platformArrow
                case 2: overlaySprite = platform5Across
                case 3: overlaySprite = platformDiagonal
                case 4: overlaySprite = platformDiagonal; flipH = true
                default: overlaySprite = platformArrow }
            }else {
                switch Int.random(min: 1, max: 4) {
                case 1: overlaySprite = break5Across
                case 2: overlaySprite = breakArrow
                case 3: overlaySprite = breakDiagonal
                case 4: overlaySprite = breakDiagonal; flipH = true
                default: overlaySprite = breakArrow }
            }
        } else {
            if Int.random(min: 1, max: 100) <= 75 {
                switch Int.random(min: 1, max: 5) {
                case 1: overlaySprite = coinArrow
                case 2: overlaySprite = coinCross
                case 3: overlaySprite = coin5Across
                case 4: overlaySprite = coinDiagonal
                case 5: overlaySprite = coinDiagonal; flipH = true
                default: overlaySprite = coinArrow }
            }else {
                switch Int.random(min: 1, max: 5) {
                case 1: overlaySprite = coinSArrow
                case 2: overlaySprite = coinS5Across
                case 3: overlaySprite = coinSCross
                case 4: overlaySprite = coinSDiagonal
                case 5: overlaySprite = coinSDiagonal; flipH = true
                default : overlaySprite = coinSArrow }
            }
        }
        if overlaySprite != nil {
            createForegroundOverlay(overlaySprite!, flipX: flipH) }
    }
    
    func bombDrop() {
        gameState = .waitingForBomb
        let scale = SKAction.scale(to: 0, duration: 0.4)
        fgNode.childNode(withName: "Title")!.run(scale)
        fgNode.childNode(withName: "Ready")!.run(
            SKAction.sequence(
                [SKAction.wait(forDuration: 0.2), scale]))
        // Bounce bomb
        let scaleUp = SKAction.scale(to: 1.25, duration: 0.25)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.25)
        let sequence = SKAction.sequence([scaleUp, scaleDown])
        let repeatSeq = SKAction.repeatForever(sequence)
        fgNode.childNode(withName: "Bomb")!.run(SKAction.unhide())
        fgNode.childNode(withName: "Bomb")!.run(repeatSeq)
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run(startGame)]))
    }
    
    func setPlayerVelocity(_ amount:CGFloat) {
        let gain: CGFloat = 2.0
        player.physicsBody!.velocity.dy = max(player.physicsBody!.velocity.dy, amount * gain)
    }
    func jumpPlayer() {
        setPlayerVelocity(650)
    }
    func boostPlayer() {
        setPlayerVelocity(1200)
    }
    func superBoostPlayer() {
        setPlayerVelocity(1700)
    }
    
    func gameOver() {
        // 1
        gameState = .gameOver
        playerState = .dead
        // 2
        physicsWorld.contactDelegate = nil
        player.physicsBody?.isDynamic = false
        // 3
        let moveUp = SKAction.moveBy(x: 0.0, y: size.height/2.0,
                                     duration: 0.5)
        moveUp.timingMode = .easeOut
        let moveDown = SKAction.moveBy(x: 0.0,
                                       y: -(size.height * 1.5),
                                       duration: 1.0)
        moveDown.timingMode = .easeIn
        player.run(SKAction.sequence([moveUp, moveDown]))
        // 4
        let gameOverSprite = SKSpriteNode(imageNamed: "GameOver")
        gameOverSprite.position = camera!.position
        gameOverSprite.zPosition = 10
        addChild(gameOverSprite)
    }
}

extension GameScene {
    
    func setupCoreMotion() {
        motionManager.accelerometerUpdateInterval = 0.2
        let queue = OperationQueue()
        motionManager.startAccelerometerUpdates(to: queue, withHandler:{ accelerometerData, error in
                guard let accelerometerData = accelerometerData else { return }
                let acceleration = accelerometerData.acceleration
                self.xAcceleration = CGFloat(acceleration.x) * 2.5 })
    }
    
    func sceneCropAmount() -> CGFloat {
        guard let view = view else { return 0 }
        let scale = view.bounds.size.height / size.height
        let scaledWidth = size.width * scale
        let scaledOverlap = scaledWidth - view.bounds.size.width
        return scaledOverlap / scale
    }
    
    func updatePlayer() {
        player.physicsBody?.velocity.dx = xAcceleration * 1000.0
        // Wrap player around edges of screen
        var playerPosition = convert(player.position, from: fgNode)
        let rightLimit = size.width/2 - sceneCropAmount()/2 + player.size.width/2
        let leftLimit = -rightLimit
        if playerPosition.x < leftLimit {
            playerPosition = convert(CGPoint(x: rightLimit, y: 0.0), to: fgNode)
            player.position.x = playerPosition.x
        }
        else if playerPosition.x > rightLimit {
            playerPosition = convert(CGPoint(x: leftLimit, y: 0.0), to: fgNode)
            player.position.x = playerPosition.x
        }
        // Check player state
        if player.physicsBody!.velocity.dy < CGFloat(0.0) && playerState != .fall {
            playerState = .fall }
        else if player.physicsBody!.velocity.dy > CGFloat(0.0) && playerState != .jump {
            playerState = .jump }
    }
}
