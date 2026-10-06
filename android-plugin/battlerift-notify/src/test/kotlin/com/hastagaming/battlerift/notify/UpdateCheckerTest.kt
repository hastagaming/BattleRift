package com.hastagaming.battlerift.notify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UpdateCheckerTest {
    private val sample =
        """{"tag_name":"v0.2.0","name":"BattleRift v0.2.0","html_url":"https://github.com/example/repo/releases/tag/v0.2.0"}"""

    @Test
    fun newerReleaseIsReported() {
        val outcome = UpdateChecker.evaluate(sample, "0.1.0")
        assertEquals(UpdateChecker.Status.NEWER, outcome.status)
        assertEquals("v0.2.0", outcome.release?.tag)
        assertEquals("https://github.com/example/repo/releases/tag/v0.2.0", outcome.release?.url)
    }

    @Test
    fun sameVersionIsCurrent() {
        assertEquals(UpdateChecker.Status.CURRENT, UpdateChecker.evaluate(sample, "0.2.0").status)
    }

    @Test
    fun malformedJsonIsAnError() {
        assertEquals(UpdateChecker.Status.ERROR, UpdateChecker.evaluate("not json", "0.1.0").status)
    }

    @Test
    fun missingTagIsAnError() {
        assertNull(UpdateChecker.parseRelease("""{"name":"x"}"""))
        assertEquals(UpdateChecker.Status.ERROR, UpdateChecker.evaluate("""{"name":"x"}""", "0.1.0").status)
    }

    @Test
    fun unknownInstalledVersionIsAnError() {
        assertEquals(UpdateChecker.Status.ERROR, UpdateChecker.evaluate(sample, "").status)
    }
}