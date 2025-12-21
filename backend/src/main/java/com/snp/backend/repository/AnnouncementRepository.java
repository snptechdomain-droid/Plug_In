package com.snp.backend.repository;

import com.snp.backend.model.Announcement;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface AnnouncementRepository extends MongoRepository<Announcement, String> {
    List<Announcement> findAllByOrderByDateDesc();

    void deleteByDateBefore(java.time.Instant date);

    void deleteByExpiryDateBefore(java.time.Instant date);
}
