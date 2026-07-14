package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, UUID> {

    List<WorkoutSession> findByUserIdOrderByCreatedAtDesc(UUID userId);

    /**
     * Detach any sessions that reference these training days (set workout_day_id = null),
     * so a day/plan can be deleted without dropping the training history logged against it.
     */
    @Modifying
    @Query("update WorkoutSession s set s.workoutDayId = null where s.workoutDayId in :dayIds")
    void detachFromDays(@Param("dayIds") List<UUID> dayIds);
}
