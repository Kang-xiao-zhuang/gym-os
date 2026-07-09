package com.zk.gymos.dto;

import com.zk.gymos.entity.Exercise;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Read model for an exercise returned to clients. */
public record ExerciseResponse(
        UUID id,
        String name,
        String bodyPart,
        String equipment,
        Short difficulty,
        String description,
        String imageUrl,
        String videoUrl,
        OffsetDateTime createdAt
) {
    public static ExerciseResponse of(Exercise e) {
        return new ExerciseResponse(
                e.getId(), e.getName(), e.getBodyPart(), e.getEquipment(), e.getDifficulty(),
                e.getDescription(), e.getImageUrl(), e.getVideoUrl(), e.getCreatedAt());
    }
}
