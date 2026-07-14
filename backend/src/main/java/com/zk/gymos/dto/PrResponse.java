package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Personal record for an exercise:
 * - weight-based: best weight ever lifted (+ reps at it) and best single-set volume;
 * - reps-based: most reps in a single set ({@code bestReps}) — the meaningful PR for bodyweight moves.
 */
public record PrResponse(
        BigDecimal maxWeight,
        Integer maxWeightReps,
        BigDecimal bestSetVolume,
        Integer bestReps,
        OffsetDateTime achievedAt
) {
}
