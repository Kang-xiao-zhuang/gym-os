# GymOS Product Requirements Document (PRD)

Version: V1.0
Author: Product Team
Project: GymOS

---

# Product Vision

GymOS is **not** a fitness community.

GymOS is a **Personal Gym Operating System**.

The goal is to help users train better, not spend more time inside the App.

Core Philosophy:

Plan → Train → Record → Analyze → Improve

Every feature should support this closed loop.

---

# Target Users

Primary Users

- Gym beginners
- Intermediate lifters
- Strength training users
- Users following Push Pull Legs / Upper Lower splits

Not Target Users

- Video course users
- Fitness influencers
- Community-first users

---

# Design Principles

1. Fast

Open App → Start Training within 5 seconds.

2. Clean

No advertisements.
No social feed.
No unnecessary information.

3. Focus

Training comes first.

4. Data Driven

Every workout should generate useful insights.

---

# Navigation

Bottom Navigation

- Today
- Plans
- Analytics
- Profile

---

# V1 Features

## Today Page

Purpose

Help users immediately start today's workout.

Display

- Greeting
- Current Workout Plan
- Current Workout Day
- Muscle Group
- Workout Duration
- Completed Sets
- Progress Bar
- Exercise Cards
- Start / Finish Workout Button

New Requirements

Instead of

Completed 0 / 1

Use

Completed Sets

Example

0 / 18 Sets

Display

Estimated Duration

Example

65 minutes

Display

Workout Volume

Example

Today's Volume

0 kg

Display

Rest Timer

Workout Time

01:20

Rest

00:45

---

## Workout Plan

Support multiple plans.

Examples

Push Pull Legs

Upper Lower

Bro Split

12 Week Program

Each Plan contains

Weeks

↓

Workout Days

↓

Exercises

Each Workout Day displays

- Estimated Time
- Number of Exercises
- Total Sets

Support

Duplicate Plan

Rename

Archive

Delete

---

## Exercise Library

Every Exercise contains

Basic Information

- Name
- Muscle Group
- Equipment
- Difficulty
- Description

Statistics

- Last Weight
- Last Reps
- Personal Record
- Favorite

Filters

Muscle Group

Equipment

Difficulty

Favorites

Search

---

## Workout Session

Start Workout

During Workout

Each Exercise

Display

Previous Performance

Example

Last Time

60 kg × 8

Current Input

Weight

Reps

Sets

Rest Timer

Complete Set

Skip Exercise

Notes

Finish Workout

Generate Summary

---

## Workout Summary

Automatically generated.

Include

Workout Time

Total Volume

Completed Sets

Average Rest Time

PR Achievements

Example

Workout Complete

Duration

72 min

Volume

12,680 kg

Completed

18 / 18 Sets

New PR

Bench Press +2.5kg

---

## Body Analytics

Track

Weight

Body Fat

Waist

Chest

Arm

Thigh

Hip

Display

Trend Charts

Weekly

Monthly

Yearly

Goal Progress

Example

Current

79 kg

Goal

75 kg

Progress

35%

---

## Profile

Profile

Avatar

Name

Email

Settings

Workout History

Exercise Management

Appearance

Logout

---

# V1.5 Features

## Progressive Overload

Core Feature

Automatically recommend next workout weight.

Rules

If all sets completed successfully

Increase weight

Example

60 × 10 × 4

↓

Next Workout

62.5 kg

If failed

Keep

or

Decrease

Recommendations should be configurable.

---

## Personal Records

Track

One Rep Max

Estimated 1RM

Best Weight

Best Volume

Best Reps

Notify users when a new PR is achieved.

---

## Workout Heatmap

GitHub Style

Display training consistency.

Monthly

Yearly

---

## Workout Volume Analytics

Track

Daily Volume

Weekly Volume

Monthly Volume

Charts

Trend

---

## Favorite Exercises

Users can pin favorite exercises.

Quick Add

---

## Workout History

Timeline

Every Workout

Display

Date

Duration

Volume

Exercises

Notes

---

# V2 Features

## AI Coach

Analyze

Workout History

Body Metrics

Recovery

Training Frequency

Generate

Weekly Summary

Monthly Summary

Training Suggestions

Recovery Advice

---

## Smart Weight Recommendation

AI predicts

Recommended Weight

Recommended Sets

Recommended Reps

Based on previous performance.

---

## Recovery Score

Integrate

Apple Health

Apple Watch

Garmin

Sleep

Heart Rate

HRV

Recommend

Heavy

Medium

Light

Rest Day

---

## Smart Daily Mission

Examples

Drink Water

Protein Goal

Workout

Sleep

Stretch

Progress

Daily Completion

---

## Notifications

Workout Reminder

Rest Timer

Recovery Reminder

Weekly Summary

PR Celebration

---

# Data Dashboard

Dashboard should display

Workout Count

Training Days

Current Streak

Workout Volume

Total Hours

Current Weight

Goal Progress

Muscle Distribution

Exercise Frequency

---

# Product Positioning

GymOS is NOT a workout recorder.

GymOS is a personal training operating system.

Every workout follows

Plan

↓

Train

↓

Record

↓

Analyze

↓

Improve

↓

Next Workout

The application should actively guide users instead of simply storing workout logs.

---

# Development Priority

Phase 1

✅ Authentication

✅ Workout Plans

✅ Exercise Library

✅ Workout Session

✅ Workout Logs

✅ Body Metrics

Phase 2

✅ Progressive Overload

✅ PR System

✅ Heatmap

✅ Analytics

Phase 3

✅ AI Coach

✅ Recovery Score

✅ Smart Suggestions

✅ Health Integration