package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * An exercise scheduled into a training day, with target volume
 * (table {@code workout_day_exercises}). References the shared {@link Exercise}.
 */
@Getter
@Setter
@Entity
@Table(name = "workout_day_exercises")
public class WorkoutDayExercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "workout_day_id")
    private UUID workoutDayId;

    @Column(name = "exercise_id")
    private UUID exerciseId;

    @Column(name = "sort_order")
    private Integer sortOrder = 1;

    @Column(name = "target_sets")
    private Integer targetSets;

    @Column(name = "target_reps")
    private Integer targetReps;

    @Column(name = "target_weight")
    private BigDecimal targetWeight;

    @Column(name = "rest_seconds")
    private Integer restSeconds = 90;
}
