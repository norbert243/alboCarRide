# Driver Tier System Implementation Guide for AlboCarRide

## Overview
A driver tier system is a gamification strategy that rewards high-performing drivers with exclusive benefits, increasing driver retention, service quality, and platform loyalty.

## Research Findings

### Industry Standards (Uber Pro, Bolt Rewards)

**Tier Structure (Industry Standard):**
- **4 Tiers:** Blue (Entry), Gold, Platinum, Diamond
- **Point-Based System:** Drivers earn points per trip
- **3-Month Evaluation Period:** Points accumulate over 3 months
- **Peak Time Multipliers:** 1-5 points depending on demand periods

**Qualification Requirements:**
- Minimum rating: 4.75-4.85 stars
- Maximum cancellation rate: 4-10%
- Completed trips threshold per tier

**Benefits by Tier:**

| Tier | Points Required | Benefits |
|------|----------------|----------|
| Blue | 0+ | Basic support, fuel discounts |
| Gold | 200+ | Priority airport pickup, enhanced support |
| Platinum | 600+ | Lower commission rates, insurance perks |
| Diamond | 1200+ | Maximum benefits, tuition coverage, VIP support |

---

## Recommended Implementation for AlboCarRide (DRC Context)

### Phase 1: Database Schema

```sql
-- Driver tier levels table
CREATE TABLE IF NOT EXISTS public.driver_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Current tier status
    current_tier TEXT DEFAULT 'bronze' CHECK (current_tier IN ('bronze', 'silver', 'gold', 'platinum')),

    -- Points system
    points_current_period INTEGER DEFAULT 0,
    points_lifetime INTEGER DEFAULT 0,

    -- Performance metrics
    trips_completed_period INTEGER DEFAULT 0,
    trips_completed_lifetime INTEGER DEFAULT 0,
    acceptance_rate NUMERIC(5, 2) DEFAULT 100.00, -- %
    cancellation_rate NUMERIC(5, 2) DEFAULT 0.00, -- %
    average_rating NUMERIC(3, 2) DEFAULT 0.00,

    -- Period tracking
    period_start_date DATE DEFAULT CURRENT_DATE,
    period_end_date DATE DEFAULT (CURRENT_DATE + INTERVAL '3 months'),

    -- Tier upgrade history
    last_tier_upgrade TIMESTAMP WITH TIME ZONE,
    tier_history JSONB DEFAULT '[]',

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(driver_id)
);

-- Tier benefits table
CREATE TABLE IF NOT EXISTS public.tier_benefits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tier_level TEXT NOT NULL CHECK (tier_level IN ('bronze', 'silver', 'gold', 'platinum')),
    benefit_type TEXT NOT NULL, -- 'commission_reduction', 'priority_dispatch', 'support', etc.
    benefit_value NUMERIC(10, 2), -- percentage or value
    benefit_description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Driver rewards history
CREATE TABLE IF NOT EXISTS public.driver_rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reward_type TEXT NOT NULL, -- 'tier_upgrade', 'bonus', 'perk_unlocked'
    tier_level TEXT,
    reward_description TEXT,
    reward_value NUMERIC(10, 2),
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_driver_tiers_driver ON public.driver_tiers(driver_id);
CREATE INDEX idx_driver_tiers_tier ON public.driver_tiers(current_tier);
CREATE INDEX idx_driver_rewards_driver ON public.driver_rewards(driver_id);
```

### Phase 2: Tier Definitions for DRC Market

```dart
// lib/models/driver_tier.dart

enum DriverTier {
  bronze,
  silver,
  gold,
  platinum;

  String get displayName {
    switch (this) {
      case DriverTier.bronze:
        return 'Bronze';
      case DriverTier.silver:
        return 'Silver';
      case DriverTier.gold:
        return 'Gold';
      case DriverTier.platinum:
        return 'Platinum';
    }
  }

  Color get color {
    switch (this) {
      case DriverTier.bronze:
        return Color(0xFFCD7F32);
      case DriverTier.silver:
        return Color(0xFFC0C0C0);
      case DriverTier.gold:
        return Color(0xFFFFD700);
      case DriverTier.platinum:
        return Color(0xFFE5E4E2);
    }
  }

  IconData get icon {
    switch (this) {
      case DriverTier.bronze:
        return Icons.military_tech;
      case DriverTier.silver:
        return Icons.workspace_premium;
      case DriverTier.gold:
        return Icons.stars;
      case DriverTier.platinum:
        return Icons.diamond;
    }
  }

  // Points required to reach this tier
  int get pointsRequired {
    switch (this) {
      case DriverTier.bronze:
        return 0;
      case DriverTier.silver:
        return 150;
      case DriverTier.gold:
        return 500;
      case DriverTier.platinum:
        return 1000;
    }
  }

  // Minimum requirements
  TierRequirements get requirements {
    switch (this) {
      case DriverTier.bronze:
        return TierRequirements(
          minRating: 0.0,
          maxCancellationRate: 100.0,
          minTrips: 0,
        );
      case DriverTier.silver:
        return TierRequirements(
          minRating: 4.5,
          maxCancellationRate: 15.0,
          minTrips: 50,
        );
      case DriverTier.gold:
        return TierRequirements(
          minRating: 4.7,
          maxCancellationRate: 10.0,
          minTrips: 150,
        );
      case DriverTier.platinum:
        return TierRequirements(
          minRating: 4.85,
          maxCancellationRate: 5.0,
          minTrips: 300,
        );
    }
  }

  // Benefits for each tier
  List<TierBenefit> get benefits {
    switch (this) {
      case DriverTier.bronze:
        return [
          TierBenefit('Basic customer support', Icons.support_agent),
          TierBenefit('Standard dispatch priority', Icons.list),
        ];
      case DriverTier.silver:
        return [
          TierBenefit('5% commission reduction', Icons.money_off),
          TierBenefit('Priority customer support', Icons.headset_mic),
          TierBenefit('Weekly performance reports', Icons.analytics),
          TierBenefit('Fuel discount partners', Icons.local_gas_station),
        ];
      case DriverTier.gold:
        return [
          TierBenefit('10% commission reduction', Icons.money_off),
          TierBenefit('Priority trip dispatch', Icons.flash_on),
          TierBenefit('VIP customer support (24/7)', Icons.support),
          TierBenefit('Free vehicle maintenance (monthly)', Icons.build),
          TierBenefit('Airport priority queue', Icons.flight),
        ];
      case DriverTier.platinum:
        return [
          TierBenefit('15% commission reduction', Icons.money_off),
          TierBenefit('Highest dispatch priority', Icons.star),
          TierBenefit('Dedicated account manager', Icons.person),
          TierBenefit('Free comprehensive insurance', Icons.shield),
          TierBenefit('Exclusive platinum events', Icons.event),
          TierBenefit('Monthly cash bonuses', Icons.attach_money),
        ];
    }
  }
}

class TierRequirements {
  final double minRating;
  final double maxCancellationRate;
  final int minTrips;

  TierRequirements({
    required this.minRating,
    required this.maxCancellationRate,
    required this.minTrips,
  });
}

class TierBenefit {
  final String description;
  final IconData icon;

  TierBenefit(this.description, this.icon);
}
```

### Phase 3: Points Calculation Logic

**Points Earning Rules:**

1. **Base Points per Trip:** 3 points
2. **Peak Hours Multiplier:** 2x (6-9 AM, 5-8 PM weekdays)
3. **Weekend Bonus:** +1 point
4. **High-Demand Areas:** +2 points (city center, airport)
5. **Long Distance (>10km):** +5 points
6. **5-Star Rating Bonus:** +2 points
7. **Consecutive Days Streak:**
   - 7 days: +10 points
   - 14 days: +25 points
   - 30 days: +100 points

**Penalties:**
- Cancellation: -5 points
- Low rating (<4 stars): -3 points
- Customer complaint: -10 points

### Phase 4: Commission Reduction Implementation

```dart
// In trip commission calculation service
double calculateCommission(Trip trip, DriverTier tier) {
  final baseCommissionRate = 0.15; // 15% base
  final tierDiscount = _getTierDiscount(tier);
  final effectiveRate = baseCommissionRate * (1 - tierDiscount);

  return trip.fare * effectiveRate;
}

double _getTierDiscount(DriverTier tier) {
  switch (tier) {
    case DriverTier.bronze:
      return 0.0; // 0% discount
    case DriverTier.silver:
      return 0.05; // 5% discount
    case DriverTier.gold:
        return 0.10; // 10% discount
    case DriverTier.platinum:
      return 0.15; // 15% discount
  }
}
```

### Phase 5: UI/UX Implementation

**Dashboard Widget:**
- Progress bar showing points toward next tier
- Current tier badge with animated shine effect
- Benefits list
- Leaderboard (optional - top drivers in area)

**Notifications:**
- Tier upgrade notifications
- Near-tier-upgrade alerts ("50 points away from Gold!")
- Weekly progress reports
- Special challenges/quests

---

## Implementation Priority

### Immediate (Week 1-2):
1. Create database schema
2. Implement basic tier assignment
3. Display current tier in driver app

### Short-term (Week 3-4):
1. Points calculation system
2. Commission reduction logic
3. Tier upgrade notifications

### Medium-term (Month 2):
1. UI enhancements (progress bars, animations)
2. Weekly challenges
3. Benefit redemption system

### Long-term (Month 3+):
1. Leaderboards
2. Special events for top tiers
3. Partnership benefits (fuel, maintenance)

---

## Key Success Metrics

1. **Driver Retention:** Target 20% increase in 6 months
2. **Service Quality:** Average rating improvement to 4.7+
3. **Driver Engagement:** 70%+ active participation in tier system
4. **Trip Volume:** 15% increase from tier-motivated drivers

---

## DRC-Specific Considerations

1. **Localized Benefits:**
   - Fuel discounts (partner with Total, Oryx)
   - Vehicle maintenance (local garages)
   - Mobile money bonuses (Airtel, Orange, M-Pesa)

2. **Accessibility:**
   - Simple, visual tier badges
   - French language support
   - Offline-compatible tier status

3. **Economic Context:**
   - Commission reductions are more valuable than perks
   - Focus on tangible financial benefits
   - Weekly cash bonuses for top performers

---

## Next Steps

1. **Get Approval:** Present this plan to stakeholders
2. **Partner Negotiations:** Secure fuel discount, maintenance partners
3. **Development:** Assign to engineering team
4. **Testing:** Beta test with 20-50 drivers
5. **Launch:** Phased rollout to all drivers

---

**Status:** Ready for implementation
**Estimated Development Time:** 6-8 weeks
**Expected Impact:** High driver retention and service quality improvement
