package com.snp.backend.repository;

import com.snp.backend.model.ScheduleEntry;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.time.LocalDateTime;
import java.util.List;

public interface ScheduleRepository extends MongoRepository<ScheduleEntry, String> {
    List<ScheduleEntry> findByDateBetween(LocalDateTime start, LocalDateTime end);
}
