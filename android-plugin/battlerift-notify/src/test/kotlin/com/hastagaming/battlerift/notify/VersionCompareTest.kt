package com.hastagaming.battlerift.notify

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VersionCompareTest {

    @Test
    fun newerMinorVersionIsDetected() {
        assertTrue(VersionCompare.isNewer("v0.2.0", "0.1.0"))
    }

    @Test
    fun sameVersionIsNotNewer() {
        assertFalse(VersionCompare.isNewer("v0.1.0", "0.1.0"))
    }

    @Test
    fun olderVersionIsNotNewer() {
        assertFalse(VersionCompare.isNewer("v0.1.0", "0.2.0"))
    }

    @Test
    fun partsAreComparedAsNumbers() {
        assertTrue(VersionCompare.isNewer("v0.1.10", "0.1.9"))
    }

    @Test
    fun missingPartsCountAsZero() {
        assertFalse(VersionCompare.isNewer("1.0", "1.0.0"))
        assertTrue(VersionCompare.isNewer("1.0.1", "1.0"))
    }

    @Test
    fun preReleaseSortsBeforeTheRelease() {
        assertFalse(VersionCompare.isNewer("v1.0.0-rc1", "1.0.0"))
        assertTrue(VersionCompare.isNewer("v1.0.0", "1.0.0-rc1"))
    }

    @Test
    fun garbageIsNeverNewer() {
        assertFalse(VersionCompare.isNewer("latest", "1.0.0"))
        assertFalse(VersionCompare.isNewer("1.0.0", ""))
    }

    @Test
    fun parseHandlesPrefixAndSuffix() {
        val parsed = VersionCompare.parse("V2.4.1+build7")
        assertNotNull(parsed)
        assertNull(VersionCompare.parse("abc"))
    }
}