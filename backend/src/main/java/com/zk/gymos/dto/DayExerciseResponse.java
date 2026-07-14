package com.zk.gymos.dto;

import com.zk.gymos.entity.Exercise;
import com.zk.gymos.entity.WorkoutDayExercise;

import java.math.BigDecimal;
import java.util.UUID;

/** A day-exercise enriched with the referenced exercise's display fields. */
public record DayExerciseResponse(
        UUID id,
        UUID exerciseId,
        String exerciseName,
        String bodyPart,
        String equipment,
        String imageUrl,
        Integer sortOrder,
        Integer targetSets,
        Integer targetReps,
        BigDecimal targetWeight,
        Integer restSeconds
) {
    public static DayExerciseResponse of(WorkoutDayExercise w, Exercise e) {
        return new DayExerciseResponse(
                w.getId(), w.getExerciseId(),
                e == null ? "(已删除动作)" : e.getName(),
                e == null ? null : e.getBodyPart(),
                e == null ? null : e.getEquipment(),
                e == null ? null : e.getImageUrl(),
                w.getSortOrder(), w.getTargetSets(), w.getTargetReps(),
                w.getTargetWeight(), w.getRestSeconds());
    }
}
