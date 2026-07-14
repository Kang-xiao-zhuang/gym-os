package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Coaching insights derived from the user's whole training history:
 * this-month body-part balance, possible plateaus, and the biggest recent gain.
 */
public record InsightsResponse(
        List<BodyPartLoad> bodyParts,
        List<Plateau> plateaus,
        Gain biggestGain
) {
    /** Sets trained for a body part this month. */
    public record BodyPartLoad(String bodyPart, int sets) {}

    /** A weighted exercise whose top weight hasn't improved over its recent sessions. */
    public record Plateau(String exerciseName, BigDecimal weight, int sessions) {}

    /** The exercise with the largest top-weight increase in the last 30 days. */
    public record Gain(String exerciseName, BigDecimal fromWeight, BigDecimal toWeight, BigDecimal delta) {}
}
