package com.snp.backend.repository;

import com.snp.backend.model.Project;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface ProjectRepository extends MongoRepository<Project, String> {
    List<Project> findByOwnerId(String ownerId);

    List<Project> findByCollaboratorIdsContaining(String userId);
}
