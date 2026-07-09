package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutDayExercise;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface WorkoutDayExerciseRepository extends JpaRepository<WorkoutDayExercise, UUID> {

    List<WorkoutDayExercise> findByWorkoutDayIdOrderBySortOrderAsc(UUID workoutDayId);

    void deleteByWorkoutDayId(UUID workoutDayId);
}
