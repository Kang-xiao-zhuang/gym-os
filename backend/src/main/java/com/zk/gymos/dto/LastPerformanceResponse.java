package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

/** The most recent time an exercise was performed: date + each set's weight×reps. */
public record LastPerformanceResponse(
        OffsetDateTime date,
        List<SetLog> sets
) {
    public record SetLog(Integer setNo, BigDecimal weight, Integer reps) {}
}
