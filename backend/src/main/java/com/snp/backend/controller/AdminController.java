package com.snp.backend.controller;

import com.snp.backend.model.User;
import com.snp.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Random;

@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/backfill-domains")
    public ResponseEntity<?> backfillDomains() {
        List<User> users = userRepository.findAll();
        // Matching domains from frontend: Management, Tech, WebDev, Content, Design,
        // Marketing
        // Using "Web Dev" as string to match existing data potentially or frontend enum
        // Checking domain.dart: 'webdev' or 'web dev'.
        // User.java stores String.
        // Let's use clean strings.
        String[] domains = { "Management", "Tech", "Web Dev", "Content", "Design", "Marketing" };
        String[] departments = { "CSE", "ECE", "MECH", "EEE", "CIVIL", "IT", "AI&DS" };
        String[] years = { "I", "II", "III", "IV" };
        String[] sections = { "A", "B", "C" };

        Random random = new Random();
        int count = 0;

        for (User u : users) {
            boolean changed = false;

            // Check if domains list is empty
            if (u.getDomains() == null || u.getDomains().isEmpty()) {
                // Determine how many domains to assign (1 or 2)
                int numDomains = random.nextInt(2) + 1; // 1 or 2
                java.util.List<String> newDomains = new java.util.ArrayList<>();

                for (int i = 0; i < numDomains; i++) {
                    String d = domains[random.nextInt(domains.length)];
                    if (!newDomains.contains(d)) {
                        newDomains.add(d);
                    }
                }

                u.setDomains(newDomains);
                changed = true;
            }

            if (u.getDepartment() == null || u.getDepartment().isEmpty()) {
                u.setDepartment(departments[random.nextInt(departments.length)]);
                changed = true;
            }

            if (u.getYear() == null || u.getYear().isEmpty()) {
                u.setYear(years[random.nextInt(years.length)]);
                changed = true;
            }

            if (u.getSection() == null || u.getSection().isEmpty()) {
                u.setSection(sections[random.nextInt(sections.length)]);
                changed = true;
            }

            if (u.getRegisterNumber() == null || u.getRegisterNumber().isEmpty()) {
                // Generate random reg number: 3123 + year(2digits) + 104 + random(3digits)
                // (Example format)
                int yearPrefix = 21 + random.nextInt(4);
                int randomId = 100 + random.nextInt(900);
                u.setRegisterNumber("3123" + yearPrefix + "104" + randomId);
                changed = true;
            }

            if (changed) {
                userRepository.save(u);
                count++;
            }
        }

        return ResponseEntity.ok("Backfilled data for " + count + " users.");
    }
}
