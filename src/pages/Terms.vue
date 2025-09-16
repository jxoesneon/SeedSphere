<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6">
      <section class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 border border-base-300/50 shadow p-6 md:p-10">
        <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">Terms of Service</h1>
        <p class="mt-3 opacity-80 max-w-prose">These Terms govern your use of SeedSphere. By using the service, you agree to these Terms.</p>
        <p class="mt-2 text-sm opacity-70">Last updated: {{ lastUpdated }}</p>
      </section>

      <section class="mt-8 grid gap-6">
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Scope</h2>
            <p class="mt-2">SeedSphere is a Stremio addon that improves stream discovery, startup speed, and reliability by aggregating sources and applying health‑based tracker selection. We personalize your addon manifest per seedling to remember preferences and bindings.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Use of the Service</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>You must comply with applicable laws and third‑party terms.</li>
              <li>You are responsible for protecting your session and for activity under your account.</li>
              <li>We may update, limit, or discontinue features to maintain reliability, security, or compliance.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Account and Authentication</h2>
            <p class="mt-2">You may sign in with Magic Link or a third‑party identity provider (for example, Google). Your use of any identity provider is subject to that provider’s terms and policies. We store only minimal identifiers (for example, provider user id and optional email) to operate the service.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Seedlings and Binding</h2>
            <p class="mt-2">A “seedling” is a per‑installation identity used to personalize your addon manifest and coordinate with your account. We may enforce a reasonable cap on seedlings per user to ensure fair use and service quality.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Acceptable Use</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>Do not abuse, harass, or interfere with service operation.</li>
              <li>Do not attempt unauthorized access or reverse engineer our infrastructure.</li>
              <li>Respect rate limits and avoid excessive automated traffic.</li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Third‑Party Services and Content</h2>
            <p class="mt-2">SeedSphere optimizes discovery; it does not host or distribute media. Content accessed via third‑party providers is your responsibility and subject to those providers’ terms. Availability of providers may change without notice.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Intellectual Property</h2>
            <p class="mt-2">SeedSphere’s software, branding, and documentation are protected by applicable intellectual property laws. Open‑source dependencies remain under their respective licenses.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Disclaimers</h2>
            <p class="mt-2">SeedSphere is provided “as is” and “as available” without warranties, express or implied. We do not warrant uninterrupted operation, compatibility, or that results will meet your requirements.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Limitation of Liability</h2>
            <p class="mt-2">To the maximum extent permitted by law, SeedSphere and its contributors will not be liable for any indirect, incidental, special, consequential, exemplary, or punitive damages, or any loss of data, use, goodwill, or profits arising from your use of the service.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Changes and Termination</h2>
            <p class="mt-2">We may update these Terms or the service. When changes are material, we will provide reasonable notice (for example, in‑app). Your continued use after changes take effect constitutes acceptance. We may suspend or terminate access for violations or to protect the service.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Governing Law</h2>
            <p class="mt-2">These Terms are governed by applicable law in your jurisdiction unless a specific venue is required by law. Local consumer protections may apply.</p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Contact</h2>
            <p class="mt-2">For questions about these Terms, contact us at the email listed in the addon manifest.</p>
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
