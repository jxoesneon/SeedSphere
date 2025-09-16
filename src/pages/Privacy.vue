<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6">
      <section class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 border border-base-300/50 shadow p-6 md:p-10">
        <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">Privacy Policy</h1>
        <p class="mt-3 opacity-80 max-w-prose">Your privacy matters. This page explains what information we collect, how we use it, and the choices you have.</p>
        <p class="mt-2 text-sm opacity-70">Last updated: {{ lastUpdated }}</p>
      </section>

      <section class="mt-8 grid gap-6">
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Scope</h2>
            <p class="mt-2">SeedSphere is a Stremio addon focused on improving stream discovery and reliability. We personalize your addon manifest per “seedling” so the addon can remember your preferences (for example, curated trackers variant) and bind your installation to your account.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Information We Process</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li><strong>Account data:</strong> email for Magic Link, or an identifier (and optional email) from an identity provider such as Google.</li>
              <li><strong>Operational metadata:</strong> coarse device fingerprint (UA + Accept‑Language + coarse IP bucket), rate‑limit counters, nonces, and minimal request details needed for security and abuse prevention.</li>
              <li><strong>Seedling data:</strong> seedling identifiers, per‑seedling configuration defaults (for example, <code>variant</code>), and bindings between seedlings and your account.</li>
              <li><strong>Stream requests:</strong> identifiers required to serve addon responses (for example, Stremio media ids like IMDb <code>tt1254207</code>). We do not build behavioral profiles from these requests.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">What We Do Not Collect</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>We do not store playback history or attempt to identify what you watch across apps.</li>
              <li>We do not embed trackers or third‑party advertising pixels.</li>
              <li>We do not sell personal information.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">How We Use Information</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>To authenticate you and maintain a secure session.</li>
              <li>To mint seedlings, bind them to your account, and personalize your manifest.</li>
              <li>To improve addon quality (for example, health‑based tracker selection, provider availability) and protect the service from abuse.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Cookies</h2>
            <p class="mt-2">We use essential cookies only: a session cookie to keep you signed in, and short‑lived cookies required by some sign‑in flows (for example, a PKCE verifier for Google). We do not use cross‑site tracking cookies.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Retention</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>Sessions: typically up to 30 days.</li>
              <li>Recent seedling window (for manifest convenience): about 10 minutes.</li>
              <li>Activity caches (presence/health maps): about 180 minutes (rolling TTL).</li>
              <li>Link tokens and nonces: minutes, for their intended security window only.</li>
              <li>Database records (for example, seedlings, bindings): retained while your account is active or until you remove the installation.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Third‑Party Services</h2>
            <p class="mt-2">If you sign in with a third‑party identity provider (for example, Google), that provider processes your information under its own privacy policy. We store only what is required to operate the service (for example, your provider user id and optional email).</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Security</h2>
            <p class="mt-2">We hash secrets with salted SHA‑256, enforce session‑based access to sensitive endpoints, apply rate limits, and mask sensitive path segments (for example, per‑seedling <code>sk</code>) in logs. No system is perfectly secure, but we continuously improve our safeguards.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Your Choices</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>You can sign out at any time from the Account menu.</li>
              <li>You can re‑mint seedlings and update configuration defaults through the onboarding and install flows.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Contact</h2>
            <p class="mt-2">For privacy questions or requests, contact us at the email listed in the addon manifest.</p>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { ref } from 'vue'

const lastUpdated = ref(new Date().toISOString().split('T')[0])
</script>

<style scoped>
</style>
