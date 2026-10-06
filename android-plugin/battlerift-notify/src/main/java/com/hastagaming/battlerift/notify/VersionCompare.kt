package com.hastagaming.battlerift.notify

object VersionCompare {
    private val PATTERN = Regex("""^[vV]?(\d+(?:\.\d+)*)([-+].*)?$""")

    data class Parsed(val parts: List<Int>, val suffix: String)

    fun parse(raw: String): Parsed? {
        val match = PATTERN.matchEntire(raw.trim()) ?: return null
        val parts = ArrayList<Int>()
        for (piece in match.groupValues[1].split('.')) {
            parts.add(piece.toIntOrNull() ?: return null)
        }
        return Parsed(parts, match.groupValues[2])
    }

    // True only when `latest` is a strictly newer release than `current`.
    // A pre-release suffix (for example "-rc1") sorts before the plain release.
    fun isNewer(latest: String, current: String): Boolean {
        val a = parse(latest) ?: return false
        val b = parse(current) ?: return false
        val size = maxOf(a.parts.size, b.parts.size)
        for (i in 0 until size) {
            val x = a.parts.getOrElse(i) { 0 }
            val y = b.parts.getOrElse(i) { 0 }
            if (x != y) {
                return x > y
            }
        }
        return a.suffix.isEmpty() && b.suffix.isNotEmpty()
    }
}