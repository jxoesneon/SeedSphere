<script setup>
import ManualTrackers from './components/ManualTrackers.vue'
</script>

<template>
  <div class="min-h-full p-6">
    <header class="mb-6">
      <h1 class="text-3xl font-semibold">SeedSphere Configure</h1>
      <p class="text-sm opacity-70">Refactored UI (Vue + Tailwind + DaisyUI)</p>
    </header>

    <section class="grid gap-6">
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title">Manual Trackers</h2>
          <ManualTrackers />
        </div>
      </div>

      <div class="alert alert-info">
        <span>Additional panels (validation, sweep, health, boosts) will follow. Current build focuses on Manual Trackers parity.</span>
      </div>
    </section>
  </div>
</template>
