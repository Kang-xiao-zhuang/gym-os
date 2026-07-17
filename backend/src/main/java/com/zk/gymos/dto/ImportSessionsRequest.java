package com.zk.gymos.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Payload for importing training sessions (from a JSON backup produced by the
 * export endpoint). Unknown fields (id/dayTitle/totalSets/totalVolume from the
 * export shape) are ignored so an exported file can be re-imported as-is.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ImportSessionsRequest(List<SessionImport> sessions) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record SessionImport(
            OffsetDateTime startedAt,
            OffsetDateTime finishedAt,
            Integer durationMinutes,
            List<ExerciseImport> exercises
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ExerciseImport(UUID exerciseId, String name, String bodyPart, List<SetImport> sets) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record SetImport(Integer setNo, BigDecimal weight, Integer reps) {}
}
