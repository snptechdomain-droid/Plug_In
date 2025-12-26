package com.snp.backend.repository;

import com.snp.backend.model.MembershipRequest;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface MembershipRequestRepository extends MongoRepository<MembershipRequest, String> {
    List<MembershipRequest> findByStatus(String status);
}
