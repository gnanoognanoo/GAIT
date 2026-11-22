#include "motion_analyzer.h"
#include "configuration.h"
void MotionAnalyzer::reset() {
  activity = 0;
  intensity = 0;
}
void MotionAnalyzer::update(FusionVector a, FusionVector g, float dt,
                            uint32_t t) {
  const float acceleration = FusionVectorNorm(a) / .65f;
  const float rotation = FusionVectorNorm(g) / 150.f;
  const float combined = fminf(
      1, sqrtf(.6f * acceleration * acceleration + .4f * rotation * rotation));
  intensity += (1 - expf(-dt / .25f)) * (combined - intensity);
  const unsigned previous = activity;
  while (activity < 3 && intensity >= config::activityThresholds[activity])
    ++activity;
  while (activity > 0 &&
         intensity < config::activityThresholds[activity - 1] * .75f)
    --activity;
  if (activity > 0 && activity != previous &&
      (!emitted || t - eventTime >= config::eventCooldownMs)) {
    ++eventId;
    eventTime = t;
    emitted = true;
  }
}
