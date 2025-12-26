package com.snp.backend.repository;

import com.snp.backend.model.Attendance;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface AttendanceRepository extends MongoRepository<Attendance, String> {
    List<Attendance> findAllByOrderByDateDesc();
}
