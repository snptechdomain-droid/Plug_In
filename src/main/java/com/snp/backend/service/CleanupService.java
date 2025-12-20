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
            // 1. Clean Announcements
            Instant announceCutoff = Instant.now().minus(retentionPeriodDays, ChronoUnit.DAYS);
            announcementRepository.deleteByDateBefore(announceCutoff);
            System.out.println("Cleaned announcements older than: " + announceCutoff);

            // 2. Clean Schedule/Calendar
            LocalDateTime scheduleCutoff = LocalDateTime.now().minusDays(retentionPeriodDays);
            scheduleRepository.deleteByDateBefore(scheduleCutoff);
            System.out.println("Cleaned schedule entries older than: " + scheduleCutoff);

            // 3. Clean Events (optional, user asked for announcements and calendar, but
            // keeping events clean is good too)
            // User request: "only from announcements and calander"
            // Wait, user said "only from announcements and calander".
            // "and also" usually implies adding to the list.
            // "delete announce ment and calander scheduled event and classes etc"
            // "save storage only from announcements and calander"
            // I will err on side of caution and clean events too if they are just "calendar
            // events".
            // But main "Event" entity might be archival?
            // "calander scheduled event" -> implies ScheduleEntry which can be type
            // 'Event'.
            // The user phrase "only from announcements and calander" suggests preserving
            // the main 'Event' records might be desired?
            // BUT ScheduleController creates an 'Event' record too for calendar items.
            // I will clean ScheduleEntry and Announcements as explicitly requested. I will
            // NOT clean the main 'Event' collection unless it's strictly linked, to avoid
            // deleting major archival events.
            // Actually, "scheduled event and classes etc" refers to ScheduleEntry.
            // I'll stick to Announcements and ScheduleEntry.

        } catch (Exception e) {
            System.err.println("Error during cleanup: " + e.getMessage());
        }
    }
}
