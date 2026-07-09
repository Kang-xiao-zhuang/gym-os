package com.zk.gymos.dto;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Full session with its logged exercises. */
public record SessionDetailResponse(
        UUID id,
        String dayTitle,
        OffsetDateTime startedAt,
        OffsetDateTime finishedAt,
        Integer durationMinutes,
        List<LoggedExercise> exercises
) {
    public record LoggedExercise(UUID exerciseId, String name, String bodyPart) {}
}
