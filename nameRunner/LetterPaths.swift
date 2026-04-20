//
//  LetterPaths.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/18/26.
//

import Foundation

/// Defines simplified letter shapes as normalized coordinate paths.
/// Each letter fits in a unit grid (width: 1.0, height: 1.4).
///
/// Every letter is a **single continuous path** — no pen lifts.
/// Retracing segments is used where needed (runner just runs the
/// same road twice). Every letter starts at bottom-left (0, 1.4)
/// and ends at bottom-right (1, 1.4) so transitions between letters
/// are smooth horizontal baseline runs.
enum LetterPaths {

    /// Each letter maps to a single continuous path of points.
    /// All letters start at (0, 1.4) and end at (1, 1.4).
    static let letters: [Character: [CGPoint]] = [
        // A: up left, top bar, down to mid, crossbar left, retrace right, down to bottom
        "A": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 0, y: 0.7),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 1, y: 1.4)
        ],
        // B: up left, top bar, right to mid, crossbar left, retrace right, down, bottom bar left, retrace right
        "B": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 0, y: 0.7),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 1, y: 1.4),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // C: up left, top bar, retrace left, down, bottom bar right
        "C": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // D: up left, top bar, down right, bottom bar left, retrace right
        "D": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4), CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // E: up left, top bar, retrace left, down to mid, mid bar, retrace left, down, bottom bar
        "E": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0.7), CGPoint(x: 1, y: 0.7),
            CGPoint(x: 0, y: 0.7), CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // F: up left, top bar, retrace left, down to mid, mid bar, retrace left, down, across bottom
        "F": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0.7), CGPoint(x: 1, y: 0.7),
            CGPoint(x: 0, y: 0.7), CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // G: up left, top bar, retrace left, down, bottom bar, up to mid, mid bar left
        "G": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 0.5, y: 0.7),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 1, y: 1.4)
        ],
        // H: down left, up to mid, crossbar, down right to bottom, up right, down to bottom
        "H": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 0.7), CGPoint(x: 1, y: 0.7),
            CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1.4)
        ],
        // I: across bottom to center, up stem, top bar, retrace center, down stem, across to end
        "I": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0.5, y: 1.4), CGPoint(x: 0.5, y: 0),
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // J: across to right, up right, top bar left, retrace right, down, bottom bar
        "J": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 1.0),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4),
            CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1.4)
        ],
        // K: down left stem, up to mid, diagonal to top-right, back to mid, diagonal to bottom-right
        "K": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 0.7), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0.7), CGPoint(x: 1, y: 1.4)
        ],
        // L: up left, down, bottom bar
        "L": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // M: up left, diagonal to mid-center, diagonal up right, down right
        "M": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0.5, y: 0.7), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4)
        ],
        // N: up left, diagonal to bottom-right, up right
        "N": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 1.4), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4)
        ],
        // O: up left, top, down right, bottom back, retrace to end
        "O": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4), CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // P: up left, top, right down to mid, crossbar left, down left, across bottom
        "P": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 0, y: 0.7),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // Q: like O but with a diagonal tail
        "Q": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4), CGPoint(x: 0, y: 1.4),
            CGPoint(x: 0.5, y: 0.7), CGPoint(x: 1, y: 1.4)
        ],
        // R: up left, top, right to mid, crossbar left, diagonal to bottom-right
        "R": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 0, y: 0.7),
            CGPoint(x: 1, y: 1.4)
        ],
        // S: across bottom, up right, mid bar left, up left, top bar right
        "S": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4), CGPoint(x: 1, y: 0.7),
            CGPoint(x: 0, y: 0.7), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0.7),
            CGPoint(x: 1, y: 0.7), CGPoint(x: 1, y: 1.4)
        ],
        // T: across bottom to center, up stem, top bar left, retrace to center, top bar right, retrace to center, down, across to end
        "T": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0.5, y: 1.4),
            CGPoint(x: 0.5, y: 0), CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0), CGPoint(x: 0.5, y: 0),
            CGPoint(x: 0.5, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // U: up left, down, bottom bar, up right
        "U": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4),
            CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1.4)
        ],
        // V: across to center-bottom, diagonal up-left to top, diagonal down to center, diagonal up-right, down to end
        "V": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0.5, y: 1.4), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4)
        ],
        // W: up left, down-diagonal, up-center, down-diagonal, up right, down right
        "W": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 0.25, y: 1.4), CGPoint(x: 0.5, y: 0.7),
            CGPoint(x: 0.75, y: 1.4), CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1.4)
        ],
        // X: diagonal to bottom-right, retrace to center, diagonal to bottom-left, diagonal to top-right, down
        "X": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 1.4), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ],
        // Y: across to center, up stem to fork, diagonal to top-left, back to fork, diagonal to top-right, down, across
        "Y": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0.5, y: 1.4),
            CGPoint(x: 0.5, y: 0.7), CGPoint(x: 0, y: 0),
            CGPoint(x: 0.5, y: 0.7), CGPoint(x: 1, y: 0),
            CGPoint(x: 0.5, y: 0.7), CGPoint(x: 0.5, y: 1.4),
            CGPoint(x: 1, y: 1.4)
        ],
        // Z: top-left, top bar, diagonal to bottom-left, bottom bar
        "Z": [
            CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1.4), CGPoint(x: 1, y: 1.4)
        ]
    ]

    /// Lays out the letters of a name side by side and returns a single
    /// continuous array of waypoints in normalized coordinates.
    ///
    /// All letters start at bottom-left and end at bottom-right, so
    /// transitions between letters are smooth horizontal baseline runs.
    static func pathForName(_ name: String) -> [CGPoint] {
        let uppercased = name.uppercased()
        let letterWidth: CGFloat = 1.0
        let spacing: CGFloat = 0.4
        var waypoints: [CGPoint] = []
        var xOffset: CGFloat = 0

        for (index, char) in uppercased.enumerated() {
            guard let path = letters[char], !path.isEmpty else {
                xOffset += letterWidth + spacing
                continue
            }

            // If this isn't the first letter, add a transition from the
            // previous letter's end to this letter's start along the baseline
            if index > 0 && !waypoints.isEmpty {
                let transitionStart = waypoints.last!
                let letterStart = CGPoint(x: path[0].x + xOffset, y: path[0].y)
                // Only add transition if the points aren't already close
                if abs(transitionStart.x - letterStart.x) > 0.01 ||
                   abs(transitionStart.y - letterStart.y) > 0.01 {
                    waypoints.append(letterStart)
                }
            }

            for point in path {
                waypoints.append(CGPoint(x: point.x + xOffset, y: point.y))
            }

            xOffset += letterWidth + spacing
        }

        return waypoints
    }
}
