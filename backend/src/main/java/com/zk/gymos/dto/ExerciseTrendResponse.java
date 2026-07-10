package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

/** Per-session history of one exercise for a small trend chart. */
public record ExerciseTrendResponse(
        List<Point> points
) {
    /** One session: its date, the top weight that day, and that day's total volume. */
    public record Point(OffsetDateTime date, BigDecimal maxWeight, BigDecimal volume) {}
}
