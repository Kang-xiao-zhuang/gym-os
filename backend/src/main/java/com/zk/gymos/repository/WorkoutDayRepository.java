package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutDay;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface WorkoutDayRepository extends JpaRepository<WorkoutDay, UUID> {

    List<WorkoutDay> findByWorkoutPlanIdOrderByWeekNoAscDayNoAsc(UUID workoutPlanId);

    void deleteByWorkoutPlanId(UUID workoutPlanId);
}
