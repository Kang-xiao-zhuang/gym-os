package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * One trained day for the month calendar: which body parts were hit (for the
 * coloured chips), the day's volume/sets, how many PRs were set, and a compact
 * list of exercises (with ids, so "repeat this workout" can prefill).
 */
public record CalendarDayResponse(
        LocalDate date,
        List<String> bodyParts,   // distinct, ordered by sets desc
        int sets,
        BigDecimal volume,
        Integer durationMinutes,
        int sessionCount,
        int prCount,
        List<ExerciseBrief> exercises
) {
    /** Compact per-exercise line for the day sheet / repeat-workout. */
    public record ExerciseBrief(UUID exerciseId, String name, String bodyPart, int sets, BigDecimal topWeight, int reps) {}
}
