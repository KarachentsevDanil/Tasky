//
//  ConfettiView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Confetti particle animation for celebrating task completion
struct ConfettiView: View {

    // MARK: - State
    @State private var animate = false
    @State private var particles: [ConfettiParticle] = []
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Properties
    let particleCount: Int
    let colors: [Color]

    // MARK: - Initialization
    init(particleCount: Int = 50, colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]) {
        self.particleCount = particleCount
        self.colors = colors
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(color: particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: animate ? particle.endX : particle.startX,
                            y: animate ? particle.endY : particle.startY
                        )
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(animate ? particle.endRotation : particle.startRotation))
                }
            }
            .onAppear {
                // Generate particles
                particles = (0..<particleCount).map { _ in
                    ConfettiParticle(
                        startX: geometry.size.width / 2,
                        startY: geometry.size.height / 2,
                        endX: CGFloat.random(in: 0...geometry.size.width),
                        endY: CGFloat.random(in: geometry.size.height...geometry.size.height * 1.5),
                        color: colors.randomElement() ?? .blue,
                        size: CGFloat.random(in: 6...12),
                        startRotation: Double.random(in: 0...360),
                        endRotation: Double.random(in: 360...720)
                    )
                }

                // Animate (skip if reduce motion is enabled)
                if reduceMotion {
                    animate = true
                } else {
                    withAnimation(.easeOut(duration: Constants.Animation.celebration)) {
                        animate = true
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Confetti Particle Model
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let startRotation: Double
    let endRotation: Double
}

// MARK: - Confetti Piece Shape
struct ConfettiPiece: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
    }
}

// MARK: - Confetti Modifier
struct ConfettiModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ConfettiView()
                        .onAppear {
                            // Auto-dismiss after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Animation.celebration) {
                                isPresented = false
                                onDismiss()
                            }
                        }
                }
            }
    }
}

// MARK: - View Extension
extension View {
    /// Show confetti animation
    func confetti(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void = {}) -> some View {
        modifier(ConfettiModifier(isPresented: isPresented, onDismiss: onDismiss))
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.white
        ConfettiView()
    }
}
