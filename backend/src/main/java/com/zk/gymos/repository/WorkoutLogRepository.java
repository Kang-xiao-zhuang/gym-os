package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {

    List<WorkoutLog> findBySessionId(UUID sessionId);

    /** All logs across many sessions in one query (avoids N+1 when listing history/insights). */
    List<WorkoutLog> findBySessionIdIn(Collection<UUID> sessionIds);

    long countBySessionId(UUID sessionId);

    void deleteBySessionId(UUID sessionId);

    /** All logs of one exercise done by one user, newest first (across sessions). */
    @Query("select l from WorkoutLog l where l.exerciseId = :exerciseId " +
           "and l.sessionId in (select s.id from WorkoutSession s where s.userId = :userId) " +
           "order by l.createdAt desc, l.setNo asc")
    List<WorkoutLog> findByUserAndExerciseNewestFirst(@Param("userId") UUID userId,
                                                       @Param("exerciseId") UUID exerciseId);
}
