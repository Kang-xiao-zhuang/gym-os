package com.zk.gymos.dto;

import com.zk.gymos.entity.WorkoutSession;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/** List row for training history. {@code prCount} = how many exercises set a new personal record this session. */
public record SessionResponse(
        UUID id,
        UUID workoutDayId,
        String dayTitle,
        OffsetDateTime startedAt,
        OffsetDateTime finishedAt,
        Integer durationMinutes,
        long totalSets,
        BigDecimal totalVolume,
        long exerciseCount,
        int prCount,
        OffsetDateTime createdAt
) {
    public static SessionResponse of(WorkoutSession s, String dayTitle, long totalSets,
                                     BigDecimal totalVolume, long exerciseCount, int prCount) {
        return new SessionResponse(s.getId(), s.getWorkoutDayId(), dayTitle,
                s.getStartedAt(), s.getFinishedAt(), s.getDurationMinutes(),
                totalSets, totalVolume, exerciseCount, prCount, s.getCreatedAt());
    }
}
