package com.snp.backend.controller;

import com.snp.backend.model.MembershipRequest;
import com.snp.backend.repository.MembershipRequestRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/membership")
@CrossOrigin(origins = "*") // Allow all origins
public class MembershipRequestController {

    @Autowired
    private MembershipRequestRepository requestRepository;

    @Autowired
    private com.snp.backend.repository.UserRepository userRepository;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @GetMapping
    public List<MembershipRequest> getAllRequests() {
        return requestRepository.findAll();
    }

    @PostMapping("/request")
    public MembershipRequest submitRequest(@RequestBody MembershipRequest request) {
        request.setStatus("PENDING");
        request.setRequestDate(LocalDateTime.now());
        return requestRepository.save(request);
    }

    @PutMapping("/{id}/status")
    public MembershipRequest updateStatus(@PathVariable String id, @RequestBody java.util.Map<String, Object> payload) {
        String status = (String) payload.getOrDefault("status", "PENDING");
        @SuppressWarnings("unchecked")
        List<String> approvedDomains = (List<String>) payload.get("approvedDomains");

        return requestRepository.findById(id).map(request -> {
            request.setStatus(status);

            if ("APPROVED".equals(status)) {
                // Check if user already exists
                if (userRepository.findByEmail(request.getEmail()).isEmpty()) {
                    com.snp.backend.model.User newUser = new com.snp.backend.model.User();

                    // Generate username (email prefix)
                    String generatedUsername = request.getName().trim().replaceAll("\\s+", "").toLowerCase()
                            + randomSuffix();
                    newUser.setEmail(request.getEmail()); // Use actual email
                    newUser.setPasswordHash(passwordEncoder
                            .encode(request.getRegisterNumber() != null ? request.getRegisterNumber() : "welcome123"));
                    newUser.setDisplayName(request.getName());
                    newUser.setRole(com.snp.backend.model.User.Role.MEMBER);

                    // Map Student Details Directly
                    newUser.setRegisterNumber(request.getRegisterNumber());
                    newUser.setDepartment(request.getDepartment());
                    newUser.setYear(request.getYear());
                    newUser.setSection(request.getSection());

                    // Map Domains (Use approved list if provided, otherwise requested list)
                    if (approvedDomains != null && !approvedDomains.isEmpty()) {
                        newUser.setDomains(approvedDomains);
                        // Update request object to reflect what was actually approved?
                        request.setDomains(approvedDomains);
                    } else {
                        newUser.setDomains(request.getDomains());
                    }

                    newUser.setActive(true);
                    newUser.setCreatedAt(java.time.Instant.now());

                    // Optional bio
                    newUser.setBio("Joined via Membership Request");

                    userRepository.save(newUser);
                }
            }

            return requestRepository.save(request);
        }).orElseThrow(() -> new RuntimeException("Request not found"));
    }

    private String randomSuffix() {
        return String.valueOf((int) (Math.random() * 1000));
    }
}
