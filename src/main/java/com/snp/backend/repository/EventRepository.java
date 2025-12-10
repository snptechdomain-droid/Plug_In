package com.snp.backend.repository;

import com.snp.backend.model.Event;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface EventRepository extends MongoRepository<Event, String> {
    List<Event> findByIsPublicTrue();
}
