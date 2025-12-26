package com.snp.backend.controller;

import com.snp.backend.model.Announcement;
import com.snp.backend.model.User;
import com.snp.backend.repository.AnnouncementRepository;
import com.snp.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/announcements")
@CrossOrigin(origins = "*")
public class AnnouncementController {

    @Autowired
    private AnnouncementRepository announcementRepository;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    public List<Announcement> getAllAnnouncements() {
        return announcementRepository.findAllByOrderByDateDesc();
    }

    @PostMapping
    public Announcement createAnnouncement(@RequestBody Announcement announcement) {
        // In a real app, we would verify the user's role from the security context
        // here.
        // For now, we rely on the frontend to check permissions, but we store the
        // author.
        if (announcement.getDate() == null) {
            announcement.setDate(Instant.now());
        }
        return announcementRepository.save(announcement);
    }

    @GetMapping("/unread-count/{userId}")
    public long getUnreadCount(@PathVariable String userId) {
        // userId here is treated as email/username from frontend
        User user = userRepository.findByEmail(userId).orElse(null);
        if (user == null || user.getLastAnnouncementRead() == null) {
            // If never read, count all (or maybe limit to recent, but all is safer)
            return announcementRepository.count();
        }

        List<Announcement> all = announcementRepository.findAllByOrderByDateDesc();
        return all.stream()
                .filter(a -> a.getDate().isAfter(user.getLastAnnouncementRead()))
                .count();
    }

    @PostMapping("/mark-read/{userId}")
    public void markAsRead(@PathVariable String userId) {
        userRepository.findByEmail(userId).ifPresent(user -> {
            user.setLastAnnouncementRead(Instant.now());
            userRepository.save(user);
        });
    }
}
