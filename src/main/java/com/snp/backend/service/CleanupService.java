package com.snp.backend.service;

import com.snp.backend.repository.AnnouncementRepository;
import com.snp.backend.repository.EventRepository;
import com.snp.backend.repository.ScheduleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

@Service
public class CleanupService {

    @Autowired
    private AnnouncementRepository announcementRepository;

    @Autowired
    private EventRepository eventRepository;

    @Autowired
    private ScheduleRepository scheduleRepository;

    // Run every day at midnight (Server time)
    @Scheduled(cron = "0 0 0 * * ?")
    public void cleanupOldData() {
        System.out.println("Starting daily cleanup of old data...");

        // Threshold: 1 day after completion
        // Use 24 hours ago as the cutoff
        long retentionPeriodDays = 1;

        try {
            // 1. Clean Announcements based on Expiry Date
            // Normal posts expire in 7 days, Schedule posts expire 1 day after event
            Instant now = Instant.now();
            announcementRepository.deleteByExpiryDateBefore(now);
            System.out.println("Cleaned expired announcements.");

            // 2. Clean Schedule/Calendar
            LocalDateTime scheduleCutoff = LocalDateTime.now().minusDays(retentionPeriodDays);
            scheduleRepository.deleteByDateBefore(scheduleCutoff);
            System.out.println("Cleaned schedule entries older than: " + scheduleCutoff);

        } catch (Exception e) {
            System.err.println("Error during cleanup: " + e.getMessage());
        }
    }
}
