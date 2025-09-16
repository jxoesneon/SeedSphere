<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="w-full max-w-6xl mx-auto px-4 md:px-6 py-6 md:py-8 space-y-6 md:space-y-8">
      <!-- Toasts -->
      <div v-if="toastMsg" class="toast toast-top toast-end z-30">
        <div class="alert" :class="toastType">{{ toastMsg }}</div>
      </div>
      <div class="flex items-center justify-between">
        <h1 class="text-3xl font-extrabold tracking-tight">Admin Dashboard</h1>
        <span class="hidden md:inline-block" aria-hidden="true"></span>
      </div>

      <!-- Overview (live) -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body space-y-4 md:space-y-6">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Overview</h2>
            <div class="flex gap-2">
              <button class="btn btn-ghost btn-sm tooltip" @click="probeProviders" :disabled="busy" :title="'Detect reachable upstream providers and measure response time'" data-tip="Detect reachable upstream providers and measure response time">Probe providers</button>
            </div>
          </div>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6">
            <div class="p-3 rounded-box bg-base-300/50">
              <div class="text-xs opacity-70">SSE status</div>
              <div class="text-lg font-semibold">
                <span :class="sseStatusClass">●</span>
                <span class="ml-2">{{ sseStatus.toUpperCase() }}</span>
              </div>
              <div class="text-xs opacity-70" :title="'Addon/server build version reported by the SSE stream'" data-tip="Addon/server build version">Server v{{ serverVersion || '—' }}</div>
            </div>
            <div class="p-3 rounded-box bg-base-300/50">
              <div class="text-xs opacity-70" :title="'Number of boost events (stream aggregations) observed in the last minute'" data-tip="Boost events per minute">Boosts / min</div>
              <div class="text-lg font-semibold" :title="'Live rate of boost events over the last minute'" data-tip="Live boosts/min">{{ boostsPerMin }}</div>
              <div class="text-xs opacity-70">Last: {{ ago(lastBoostTs) }}</div>
            </div>
            <div class="p-3 rounded-box bg-base-300/50">
              <div class="text-xs opacity-70" :title="'How long since the last SSE ping event arrived'" data-tip="Time since last SSE ping">Last ping</div>
              <div class="text-lg font-semibold">{{ ago(lastPingTs) }}</div>
              <div class="text-xs opacity-70">Clients: {{ sseClients || 1 }}</div>
            </div>
            <div class="p-3 rounded-box bg-base-300/50">
              <div class="text-xs opacity-70" :title="'Number of providers reachable out of total and their average latency'" data-tip="Reachable providers / avg ms">Providers (probe)</div>
              <div class="text-lg font-semibold">{{ providersOk }}/{{ providersTotal }}</div>
              <div class="text-xs opacity-70">Avg {{ providersAvgMs }} ms</div>
            </div>
          </div>
          <!-- Boosts/min history sparkline -->
          <div class="mt-3 md:mt-4">
            <div class="opacity-70 text-xs mb-1" :title="'Rolling history of boosts/min captured every 10 seconds (last hour)'
            " data-tip="Boosts/min history (last hour)">Boosts/min history</div>
            <svg :width="chartW" :height="chartH">
              <path :d="sparklinePath(bpmHistory.map((v,i)=>({c:v})))" stroke="currentColor" fill="none" stroke-width="2" />
            </svg>
          </div>
          <!-- Scoped boosts monitor -->
          <div class="mt-3 md:mt-4 grid md:grid-cols-3 gap-3 md:gap-4">
            <div class="form-control">
              <label class="label" for="scope-seedling-id"><span class="label-text">Seedling ID (scope)</span></label>
              <div class="join w-full">
                <input id="scope-seedling-id" name="scope_seedling_id" class="input input-sm input-bordered join-item w-full tooltip" v-model="scopeSeedlingId" placeholder="e.g. WqHjfXUl5WAdWUSa" :title="'Seedling install_id to scope the live boosts stream'" aria-label="Seedling ID (scope)" data-tip="Seedling scope" />
                <select id="scope-seedling-select" name="scope_seedling_select" class="select select-sm select-bordered join-item tooltip" v-model="scopeSeedlingId" :title="'Pick a known installation to scope SSE monitoring'" aria-label="Pick seedling" data-tip="Pick seedling">
                  <option value="">(select from installs)</option>
                  <option v-for="s in installations" :key="s.install_id" :value="s.install_id">{{ s.install_id }}</option>
                </select>
              </div>
            </div>
            <div class="flex items-end gap-2">
              <button class="btn btn-sm tooltip" @click="connectBoostsSse(scopeSeedlingId)" :disabled="busy" :title="'Connect SSE to scoped boosts stream for this seedling'" data-tip="Connect to seedling SSE">Connect scoped</button>
              <button class="btn btn-sm btn-ghost tooltip" @click="connectBoostsSse('')" :disabled="busy" :title="'Connect SSE to global boosts stream'" data-tip="Connect global SSE">Connect global</button>
              <button class="btn btn-sm btn-outline tooltip" @click="disconnectBoostsSse" :disabled="!esBoosts" :title="'Close current SSE connection'" data-tip="Disconnect SSE">Disconnect</button>
            </div>
          </div>
          <!-- Providers detail list -->
          <div class="mt-3 md:mt-4 overflow-x-auto rounded-box bg-base-300/40 p-2 md:p-3">
            <table class="table table-xs">
              <thead><tr><th :title="'Provider module name'" data-tip="Provider">Name</th><th :title="'Reachable or not in probe window'" data-tip="Status">Status</th><th :title="'Probe roundtrip time in milliseconds'" data-tip="Latency (ms)">ms</th></tr></thead>
              <tbody>
                <tr v-for="p in providersDetails" :key="p.name">
                  <td>{{ p.name }}</td>
                  <td>
                    <span :class="p.ok ? 'badge badge-success badge-xs' : 'badge badge-error badge-xs'">{{ p.ok ? 'ok' : 'fail' }}</span>
                  </td>
                  <td>{{ p.ms }}</td>
                </tr>
                <tr v-if="!providersDetails.length"><td colspan="3" class="opacity-60">No probe yet</td></tr>
              </tbody>
            </table>
          </div>

          <!-- Boosts/hour heatmap and Recent installs/errors/fallbacks -->
          <div class="mt-4 grid md:grid-cols-4 gap-4 md:gap-6">
            <!-- Heatmap -->
            <div class="p-3 rounded-box bg-base-300/40">
              <div class="font-semibold mb-2">Boosts per min (last hour)</div>
              <div class="grid grid-cols-10 gap-1">
                <div v-for="(v, idx) in boostsHourBins" :key="idx" class="w-5 h-5 rounded"
                  :title="`${v} in bin`"
                  :style="{ backgroundColor: heatColor(v) }"></div>
              </div>
              <div class="text-xs opacity-70 mt-1">Darker = more boosts</div>
            </div>
            <!-- Recent installations quick list -->
            <div class="p-3 rounded-box bg-base-300/40">
              <div class="font-semibold mb-2">Recent installations</div>
              <ul class="text-xs space-y-1 max-h-40 overflow-auto">
                <li v-for="s in installations.slice(0, 6)" :key="s.install_id" class="flex items-center justify-between gap-2">
                  <span class="font-mono truncate" :title="s.install_id">{{ s.install_id }}</span>
                  <div class="flex gap-1">
                    <RouterLink class="btn btn-ghost btn-xxs tooltip" :to="`/start?sid=${encodeURIComponent(s.install_id)}`" :title="'Open onboarding using this installation id'" data-tip="Onboard">Onboard</RouterLink>
                    <button class="btn btn-ghost btn-xxs tooltip" @click="() => copyText(s.install_id)" :title="'Copy this installation id to clipboard'" data-tip="Copy install id">Copy ID</button>
                  </div>
                </li>
                <li v-if="installations.length===0" class="opacity-60">No installations</li>
              </ul>
            </div>
            <!-- Recent errors by event -->
            <div class="p-3 rounded-box bg-base-300/40">
              <div class="flex items-center justify-between mb-2">
                <div class="font-semibold">Recent events (audit)</div>
                <div class="flex items-center gap-2">
                  <select id="errors-minutes" name="errors_minutes" class="select select-xxs select-bordered tooltip" v-model.number="errorsMinutes" @change="loadErrorsSummary" :title="'Window of time to summarize recent audit events'" aria-label="Errors window (minutes)" data-tip="Errors window">
                    <option :value="15">15m</option>
                    <option :value="60">1h</option>
                    <option :value="240">4h</option>
                    <option :value="720">12h</option>
                    <option :value="1440">24h</option>
                  </select>
                  <button class="btn btn-ghost btn-xxs tooltip" @click="loadErrorsSummary" :disabled="busy" :title="'Reload recent events summary for the selected window'" data-tip="Reload errors">Reload</button>
                </div>
              </div>
              <table class="table table-xxs">
                <thead><tr><th>Event</th><th>Count</th></tr></thead>
                <tbody>
                  <tr v-for="(cnt, name) in auditSummary" :key="name"><td>{{ name }}</td><td>{{ cnt }}</td></tr>
                  <tr v-if="!Object.keys(auditSummary).length"><td colspan="2" class="opacity-60">No events</td></tr>
                </tbody>
              </table>
            </div>

            <!-- Fallback reasons summary -->
            <div class="p-3 rounded-box bg-base-300/40">
              <div class="flex items-center justify-between mb-2">
                <div class="font-semibold">Fallback reasons</div>
                <div class="flex items-center gap-2">
                  <select id="fallback-minutes" name="fallback_minutes" class="select select-xxs select-bordered tooltip" v-model.number="fallbackMinutes" @change="loadFallbackSummary" :title="'Window of time to summarize fallback reasons'" aria-label="Fallbacks window (minutes)" data-tip="Fallbacks window">
                    <option :value="15">15m</option>
                    <option :value="60">1h</option>
                    <option :value="240">4h</option>
                    <option :value="720">12h</option>
                    <option :value="1440">24h</option>
                  </select>
                  <button class="btn btn-ghost btn-xxs tooltip" @click="loadFallbackSummary" :disabled="busy" :title="'Reload fallback reasons summary for the selected window'" data-tip="Reload fallbacks">Reload</button>
                </div>
              </div>
              <table class="table table-xxs">
                <thead><tr><th>Reason</th><th>Count</th></tr></thead>
                <tbody>
                  <tr v-for="(cnt, name) in fallbackSummary" :key="name"><td>{{ name }}</td><td>{{ cnt }}</td></tr>
                  <tr v-if="!Object.keys(fallbackSummary).length"><td colspan="2" class="opacity-60">No data</td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- Gardeners (admin only) -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Gardeners</h2>
            <div class="flex gap-2 items-center flex-wrap">
              <div class="join">
                <input id="gardeners-search" name="gardeners_search" class="input input-sm input-bordered join-item tooltip" placeholder="Search gardener id or platform" v-model="gardenerQuery" :title="'Filter gardeners by id or platform'" aria-label="Search gardeners" data-tip="Filter gardeners"/>
                <button class="btn btn-ghost btn-sm join-item tooltip" @click="gardenerQuery=''; loadGardeners(true)" :disabled="!gardenerQuery" :title="'Clear gardeners search'" data-tip="Clear">✕</button>
              </div>
              <label class="label cursor-pointer gap-2 items-center tooltip" :title="'Show only gardeners that have one or more bindings'" data-tip="Has bindings">
                <span class="label-text text-xs">Has bindings</span>
                <input id="gardeners-has-bindings" name="gardeners_has_bindings" type="checkbox" class="toggle toggle-xs" v-model="gardenerHasBindingsOnly" />
              </label>
              <label class="label cursor-pointer gap-2 items-center tooltip" :title="'Show only gardeners whose last_seen is older than the threshold'" data-tip="Stale only">
                <span class="label-text text-xs">Stale only</span>
                <input id="gardeners-stale-only" name="gardeners_stale_only" type="checkbox" class="toggle toggle-xs" v-model="gardenerStaleOnly" />
              </label>
              <div class="form-control">
                <label class="label" for="gardeners-stale-min"><span class="label-text text-xs">Stale if older than (minutes)</span></label>
                <input id="gardeners-stale-min" name="gardeners_stale_min" type="number" min="1" class="input input-xs input-bordered w-28" v-model.number="gardenerStaleMinutes" />
              </div>
              <div class="form-control">
                <label class="label" for="gardeners-stale-preset"><span class="label-text text-xs">Preset</span></label>
                <select id="gardeners-stale-preset" class="select select-xs select-bordered w-28" @change="applyStalePreset($event)">
                  <option value="">(select)</option>
                  <option value="15">15m</option>
                  <option value="60">1h</option>
                  <option value="240">4h</option>
                  <option value="720">12h</option>
                  <option value="1440">24h</option>
                </select>
              </div>
              <button class="btn btn-ghost btn-sm tooltip" @click="loadGardeners(true)" :disabled="busy" :title="'Reload gardeners list from server'" data-tip="Reload gardeners">Refresh</button>
              <div class="join">
                <button class="btn btn-outline btn-sm join-item tooltip" @click="exportGardenersCsv" :disabled="busy || !gardenersFiltered.length" :title="'Download the visible gardeners as CSV'" data-tip="Export gardeners">Export CSV</button>
                <button class="btn btn-ghost btn-sm join-item tooltip" @click="copyGardenersCsv" :disabled="busy || !gardenersFiltered.length" :title="'Copy the visible gardeners as CSV to clipboard'" data-tip="Copy CSV">Copy CSV</button>
              </div>
            </div>
          </div>
          <div class="text-xs opacity-70 mt-1 flex items-center gap-2">
            <span>Showing {{ gardenersFiltered.length }} of {{ gardeners.length }} gardeners</span>
            <div class="flex items-center gap-2">
              <span class="opacity-60">Selected: {{ selectedGardeners.size }}</span>
              <button class="btn btn-ghost btn-xs tooltip" :disabled="busy || selectedGardeners.size===0" @click="bulkUnlinkAll" :title="'Unlink all bindings for selected gardeners'" data-tip="Bulk unlink all">Bulk Unlink All</button>
              <button class="btn btn-error btn-xs tooltip" :disabled="busy || selectedGardeners.size===0" @click="bulkDeleteGardeners" :title="'Delete selected gardeners and their bindings'" data-tip="Bulk delete">Bulk Delete</button>
            </div>
            <div class="join">
              <button class="btn btn-ghost btn-xs join-item" @click="prevGardeners" :disabled="busy || gardenerOffset===0">Prev</button>
              <button class="btn btn-ghost btn-xs join-item" disabled>Page {{ gardenerPage }}</button>
              <button class="btn btn-ghost btn-xs join-item" @click="nextGardeners" :disabled="busy || gardeners.length < gardenerLimit">Next</button>
            </div>
            <select class="select select-xxs select-bordered" v-model.number="gardenerLimit">
              <option :value="25">25</option>
              <option :value="50">50</option>
              <option :value="100">100</option>
            </select>
          </div>
          <div class="overflow-x-auto mt-2">
            <table class="table admin-table table-sm w-full text-left">
              <colgroup>
                <col style="width: 28ch" />
                <col style="width: 20ch" />
                <col style="width: 12ch" />
                <col style="width: 14ch" />
                <col style="width: 10ch" />
                <col style="width: 12ch" />
              </colgroup>
              <thead>
                <tr class="sticky top-0 bg-base-200 z-10">
                  <th>
                    <input type="checkbox" class="checkbox checkbox-xs" :checked="allGardenersSelected" @change="toggleSelectAll($event)"/>
                  </th>
                  <th>Gardener</th>
                  <th>User</th>
                  <th>Platform</th>
                  <th>Created</th>
                  <th>Seen</th>
                  <th>Bindings</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="g in gardenersFiltered" :key="g.gardener_id" class="hover">
                  <td>
                    <input type="checkbox" class="checkbox checkbox-xs" :checked="selectedGardeners.has(g.gardener_id)" @change="toggleSelectOne(g.gardener_id, $event)"/>
                  </td>
                  <td class="font-mono text-xs break-words" :title="g.gardener_id">{{ g.gardener_id }}</td>
                  <td class="font-mono text-xs" :title="g.user_id || '—'">{{ g.user_id || '—' }}</td>
                  <td>{{ g.platform || '—' }}</td>
                  <td class="whitespace-nowrap" :title="ts(g.created_at)">{{ ts(g.created_at) }}</td>
                  <td class="whitespace-nowrap" :title="ts(g.last_seen)">{{ ts(g.last_seen) }}</td>
                  <td class="whitespace-nowrap">{{ g.bindings_count }}</td>
                  <td>
                    <button class="btn btn-ghost btn-xs tooltip" @click="openGardener(g)" :title="'Open details for this gardener'" data-tip="Open gardener">Open</button>
                  </td>
                </tr>
                <tr v-if="!gardenersFiltered.length"><td colspan="7" class="opacity-60">No gardeners</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Settings (admin only) -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Settings</h2>
            <div class="flex gap-2">
              <button class="btn btn-ghost btn-sm tooltip" @click="loadSettings" :disabled="busy" :title="'Fetch settings from server (cache table)'" data-tip="Reload settings">Reload</button>
              <button class="btn btn-primary btn-sm tooltip" @click="saveSettings" :disabled="busy" :title="'Persist admin settings to the server cache'" data-tip="Save settings">Save</button>
              <button class="btn btn-outline btn-sm tooltip" @click="refreshTrackers" :disabled="busy" :title="'Refresh trackers list cache for default variant'" data-tip="Refresh trackers">Refresh trackers</button>
            </div>
          </div>
          <div class="grid md:grid-cols-3 gap-4 md:gap-6">
            <div>
              <h3 class="font-semibold mb-2">Providers & Performance</h3>
              <label class="form-control">
                <span class="label-text tooltip" :title="'Controls responsive upstream provider detection: off, on, or auto (on during warm-up only)'" data-tip="Probe providers mode">Probe providers</span>
                <select class="select select-sm select-bordered" v-model="settings.probe_providers" name="probe_providers" aria-label="Probe providers">
                  <option value="off">off</option>
                  <option value="auto">auto</option>
                  <option value="on">on</option>
                </select>
              </label>
              <label class="form-control mt-2">
                <span class="label-text tooltip" :title="'Timeout for each provider probe request (lower = faster feedback, higher = more accurate)'
                " data-tip="Probe timeout (ms)">Probe timeout (ms)</span>
                <input type="number" class="input input-sm input-bordered" v-model.number="settings.probe_timeout_ms" name="probe_timeout_ms" aria-label="Probe timeout (ms)" />
              </label>
              <label class="form-control mt-2">
                <span class="label-text tooltip" :title="'Timeout for fetching streams from each provider (tune to balance speed vs completeness)'" data-tip="Provider fetch timeout">Provider fetch timeout (ms)</span>
                <input type="number" class="input input-sm input-bordered" v-model.number="settings.provider_fetch_timeout_ms" name="provider_fetch_timeout_ms" aria-label="Provider fetch timeout (ms)" />
              </label>
            </div>
            <div>
              <h3 class="font-semibold mb-2">Swarm & Sorting</h3>
              <label class="form-control">
                <span class="label-text tooltip" :title="'Enable optional peer swarm scraping to fill missing seeds/peers info'" data-tip="Enable swarm scraping">Swarm enabled</span>
                <select class="select select-sm select-bordered" v-model="settings.swarm_enabled" name="swarm_enabled" aria-label="Swarm enabled">
                  <option value="off">off</option>
                  <option value="on">on</option>
                </select>
              </label>
              <div class="grid grid-cols-2 gap-2 mt-2">
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Limit swarm scraping to the first N streams to reduce overhead'" data-tip="Scrape top N">Swarm top N</span>
                  <input type="number" class="input input-sm input-bordered" v-model.number="settings.swarm_top_n" name="swarm_top_n" aria-label="Swarm top N" />
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Time budget for swarm scraping; higher improves accuracy but costs time'" data-tip="Swarm timeout (ms)">Swarm timeout (ms)</span>
                  <input type="number" class="input input-sm input-bordered" v-model.number="settings.swarm_timeout_ms" name="swarm_timeout_ms" aria-label="Swarm timeout (ms)" />
                </label>
              </div>
              <label class="form-control mt-2">
                <span class="label-text tooltip" :title="'Scrape swarm only for streams where upstream lacks seeds/peers'" data-tip="Scrape only when missing">Only when missing seeds</span>
                <select class="select select-sm select-bordered" v-model="settings.swarm_missing_only" name="swarm_missing_only" aria-label="Only when missing seeds">
                  <option value="on">on</option>
                  <option value="off">off</option>
                </select>
              </label>
              <div class="grid grid-cols-2 gap-2 mt-2">
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Sort direction applied to ranking fields'" data-tip="Sort order">Sort order</span>
                  <select class="select select-sm select-bordered" v-model="settings.sort_order" name="sort_order" aria-label="Sort order">
                    <option value="desc">desc</option>
                    <option value="asc">asc</option>
                  </select>
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Comma-separated ranking fields in priority order'" data-tip="Sort fields">Sort fields</span>
                  <input type="text" class="input input-sm input-bordered" v-model="settings.sort_fields" name="sort_fields" aria-label="Sort fields" />
                </label>
              </div>
            </div>
            <div>
              <h3 class="font-semibold mb-2">AI / Telemetry / UI</h3>
              <div class="grid grid-cols-2 gap-2">
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Enables AI enhanced descriptions; may increase latency and require external API'" data-tip="Enable AI">AI enabled</span>
                  <select class="select select-sm select-bordered" v-model="settings.ai_enabled" name="ai_enabled" aria-label="AI enabled">
                    <option value="off">off</option>
                    <option value="on">on</option>
                  </select>
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Provider for AI descriptions (e.g., openai, anthropic)'" data-tip="AI provider">AI provider</span>
                  <input type="text" class="input input-sm input-bordered" v-model="settings.ai_provider" name="ai_provider" aria-label="AI provider" />
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Model identifier for the chosen provider'" data-tip="AI model">AI model</span>
                  <input type="text" class="input input-sm input-bordered" v-model="settings.ai_model" name="ai_model" aria-label="AI model" />
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Time budget for AI description generation'" data-tip="AI timeout (ms)">AI timeout (ms)</span>
                  <input type="number" class="input input-sm input-bordered" v-model.number="settings.ai_timeout_ms" name="ai_timeout_ms" aria-label="AI timeout (ms)" />
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'How long to cache AI results to avoid repeated calls'" data-tip="AI cache TTL (ms)">AI cache TTL (ms)</span>
                  <input type="number" class="input input-sm input-bordered" v-model.number="settings.ai_cache_ttl_ms" name="ai_cache_ttl_ms" aria-label="AI cache TTL (ms)" />
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Fraction of telemetry events to record/forward (0 to disable, 1 to record all)'
                  " data-tip="Telemetry sample">Telemetry sample (0..1)</span>
                  <input type="number" step="0.1" min="0" max="1" class="input input-sm input-bordered" v-model.number="settings.telemetry_sample" name="telemetry_sample" aria-label="Telemetry sample" />
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Toggles Ko‑fi support overlay across the app (disabled on /s/* routes)'
                  " data-tip="Ko‑fi overlay">Ko‑fi overlay</span>
                  <select class="select select-sm select-bordered" v-model="settings.kofi_overlay" name="kofi_overlay" aria-label="Ko‑fi overlay">
                    <option value="on">on</option>
                    <option value="off">off</option>
                  </select>
                </label>
                <label class="form-control">
                  <span class="label-text tooltip" :title="'Upper limit of active installations (seedlings) a single user can mint'" data-tip="Max seedlings per user">Max seedlings / user</span>
                  <input type="number" class="input input-sm input-bordered" v-model.number="settings.max_seedlings_per_user" name="max_seedlings_per_user" aria-label="Max seedlings per user" />
                </label>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Auth states -->
      <div v-if="!isAuthed" class="alert alert-info">
        <div class="flex items-center justify-between w-full">
          <div>
            <div class="font-semibold">Sign in required</div>
            <div class="text-sm opacity-80">Only the admin account can access the dashboard.</div>
          </div>
          <div class="flex gap-2">
            <button class="btn btn-primary btn-sm" @click="loginGoogle">Sign in with Google</button>
            <div class="join">
              <label for="magic-email" class="sr-only">Email address</label>
              <input id="magic-email" name="magic_email" class="input input-sm input-bordered join-item" type="email" v-model="magicEmail" placeholder="you@example.com" aria-label="Email address"/>
              <button class="btn btn-sm join-item" @click="startMagic">Magic Link</button>
            </div>
          </div>
        </div>
      </div>

      <div v-else-if="!isAllowed" class="alert alert-warning">
        <div class="flex items-center justify-between w-full">
          <div>
            <div class="font-semibold">Forbidden</div>
            <div class="text-sm opacity-80">Your account ({{ userLabel }}) is not allowed to access Admin. Please switch accounts.</div>
          </div>
          <button class="btn btn-ghost btn-sm" @click="logout">Sign out</button>
        </div>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

      <!-- Summary cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="card bg-base-200">
          <div class="card-body p-4">
            <div class="text-sm opacity-70">Users</div>
            <div class="text-2xl font-bold">{{ summary.counts.users ?? '—' }}</div>
          </div>
        </div>
        <div class="card bg-base-200">
          <div class="card-body p-4">
            <div class="text-sm opacity-70">Installations</div>
            <div class="text-2xl font-bold">{{ summary.counts.installations ?? '—' }}</div>
          </div>
        </div>
        <div class="card bg-base-200">
          <div class="card-body p-4">
            <div class="text-sm opacity-70">Revoked</div>
            <div class="text-2xl font-bold">{{ summary.counts.revoked ?? '—' }}</div>
          </div>
        </div>
        <div class="card bg-base-200">
          <div class="card-body p-4">
            <div class="text-sm opacity-70">Pairings</div>
            <div class="text-2xl font-bold">{{ summary.counts.pairings ?? '—' }}</div>
          </div>
        </div>
      </div>

      <!-- Users table -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Users</h2>
            <div class="flex gap-2 items-center flex-wrap">
              <div class="join">
                <input id="users-search" name="users_search" class="input input-sm input-bordered join-item tooltip" placeholder="Search email or id" v-model="userQuery" :title="'Filter users by id or email'" aria-label="Search users" data-tip="Filter users"/>
                <button class="btn btn-ghost btn-sm join-item tooltip" @click="userQuery=''; saveUsersPrefs()" :disabled="!userQuery" :title="'Clear user search'" data-tip="Clear">✕</button>
              </div>
              <select id="users-provider" name="users_provider" class="select select-sm select-bordered tooltip w-28 md:w-32" v-model="userProviderFilter" :title="'Filter by provider'" aria-label="Filter by provider" data-tip="Provider">
                <option value="all">All providers</option>
                <option v-for="p in userProviders" :key="p" :value="p">{{ p }}</option>
              </select>
              <label class="label cursor-pointer gap-2 items-center tooltip" :title="'Show only users that have an email'" data-tip="Has email">
                <span class="label-text text-xs">Has email</span>
                <input id="users-has-email" name="users_has_email" type="checkbox" class="toggle toggle-xs" v-model="userHasEmailOnly" />
              </label>
              
              <label class="label cursor-pointer gap-2 items-center tooltip" :title="'Show only users that are currently banned'" data-tip="Banned only">
                <span class="label-text text-xs">Banned only</span>
                <input id="users-only-banned" name="users_only_banned" type="checkbox" class="toggle toggle-xs" v-model="userOnlyBanned" />
              </label>
              <button class="btn btn-ghost btn-sm tooltip" @click="resetUsersFilters" :disabled="busy" :title="'Reset all user filters (search, provider, toggles)'" data-tip="Reset filters">Reset</button>
              <button class="btn btn-outline btn-sm tooltip" @click="exportUsersCsv" :disabled="busy || !usersFiltered.length" :title="'Download the visible users as CSV'" data-tip="Export users">Export CSV</button>
              <button class="btn btn-ghost btn-sm tooltip" @click="loadUsers" :disabled="busy" :title="'Reload users list from server'" data-tip="Reload users">Refresh</button>
            </div>
          </div>
          <div class="text-xs opacity-70 mt-1">Showing {{ usersFiltered.length }} of {{ users.length }} users</div>
          <div class="overflow-x-auto mt-2">
            <table class="table admin-table table-sm w-full text-left">
              <colgroup>
                <col style="width: 24ch" />
                <col style="width: 10ch" />
                <col style="width: 20ch" />
                <col style="width: 16ch" />
                <col style="width: 28ch" />
              </colgroup>
              <thead>
                <tr class="sticky top-0 bg-base-200 z-10">
                  <th
                    class="px-2 col-id cursor-pointer select-none"
                    :title="'Unique user id (provider:id)'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(userSortKey, 'id', userSortDir)"
                    @click="toggleUserSort('id')"
                    @keydown.enter.prevent="toggleUserSort('id')"
                    @keydown.space.prevent="toggleUserSort('id')"
                  >
                    ID
                    <span class="ml-1 opacity-70" v-if="userSortKey==='id'">{{ userSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'Authentication provider for this user'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(userSortKey, 'provider', userSortDir)"
                    @click="toggleUserSort('provider')"
                    @keydown.enter.prevent="toggleUserSort('provider')"
                    @keydown.space.prevent="toggleUserSort('provider')"
                  >
                    Provider
                    <span class="ml-1 opacity-70" v-if="userSortKey==='provider'">{{ userSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'Email associated to the account (if any)'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(userSortKey, 'email', userSortDir)"
                    @click="toggleUserSort('email')"
                    @keydown.enter.prevent="toggleUserSort('email')"
                    @keydown.space.prevent="toggleUserSort('email')"
                  >
                    Email
                    <span class="ml-1 opacity-70" v-if="userSortKey==='email'">{{ userSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'When the user record was created (local time)'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(userSortKey, 'created_at', userSortDir)"
                    @click="toggleUserSort('created_at')"
                    @keydown.enter.prevent="toggleUserSort('created_at')"
                    @keydown.space.prevent="toggleUserSort('created_at')"
                  >
                    Created
                    <span class="ml-1 opacity-70" v-if="userSortKey==='created_at'">{{ userSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th :title="'Available actions for this user'">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="u in usersPaged" :key="u.id" :class="['hover', u.banned ? 'bg-error/10' : '']">
                  <td class="col-id font-mono text-xs whitespace-nowrap px-2" :title="u.id">{{ userIdOnly(u) }}</td>
                  <td class="whitespace-nowrap" :title="String(u.provider||'')">{{ u.provider }}</td>
                  <td class="font-mono text-xs break-words" :title="String(u.email||'')">
                    {{ u.email || '—' }}

async function assignGardenerUser() {
  try {
    if (!gardenerDetails.value || !gardenerAssignUserId.value) return
    busy.value = true
    const gid = gardenerDetails.value.gardener_id
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}/user`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'include', body: JSON.stringify({ user_id: gardenerAssignUserId.value }) })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'assign_failed')
    toastType.value = 'alert-success'; toastMsg.value = 'User assigned'
    await openGardener({ gardener_id: gid })
    await loadGardeners(true)
  } catch (e) { toastType.value = 'alert-error'; toastMsg.value = 'Failed to assign user' } finally { busy.value = false }
}

async function clearGardenerUser() {
  try {
    if (!gardenerDetails.value) return
    busy.value = true
    const gid = gardenerDetails.value.gardener_id
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}/user`, { method: 'DELETE', credentials: 'include' })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'clear_failed')
    gardenerAssignUserId.value = ''
    toastType.value = 'alert-success'; toastMsg.value = 'User cleared'
    await openGardener({ gardener_id: gid })
    await loadGardeners(true)
  } catch (e) { toastType.value = 'alert-error'; toastMsg.value = 'Failed to clear user' } finally { busy.value = false }
}

async function unlinkAllBindings() {
  try {
    if (!gardenerDetails.value) return
    if (!confirm('Unlink all bindings for this gardener?')) return
    busy.value = true
    const gid = gardenerDetails.value.gardener_id
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}/bindings`, { method: 'DELETE', credentials: 'include' })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'unlink_all_failed')
    toastType.value = 'alert-success'; toastMsg.value = 'All bindings unlinked'
    await openGardener({ gardener_id: gid })
    await loadGardeners(true)
  } catch (e) { toastType.value = 'alert-error'; toastMsg.value = 'Failed to unlink all' } finally { busy.value = false }
}

async function deleteGardener() {
  try {
    if (!gardenerDetails.value) return
    const gid = gardenerDetails.value.gardener_id
    if (!confirm(`Delete gardener ${gid}? This will remove all bindings.`)) return
    busy.value = true
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}`, { method: 'DELETE', credentials: 'include' })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'delete_failed')
    toastType.value = 'alert-success'; toastMsg.value = 'Gardener deleted'
    try { (gardenerDlg.value && gardenerDlg.value.close) && gardenerDlg.value.close() } catch (_) {}
    gardenerDetails.value = null
    await loadGardeners(true)
  } catch (e) { toastType.value = 'alert-error'; toastMsg.value = 'Failed to delete gardener' } finally { busy.value = false }
}
                    <span v-if="u.banned" class="badge badge-error badge-ghost badge-xxs ml-1">banned</span>
                  </td>
                  <td class="whitespace-nowrap" :title="ts(u.created_at)">{{ ts(u.created_at) }}</td>
                  <td class="flex flex-wrap items-center gap-1.5">
                    <!-- Open details -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="openUser(u)"
                      :title="'Open : View user details and seedlings'"
                      data-tip="Open : View user details and seedlings"
                      aria-label="Open user details"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12s3.75-6.75 9.75-6.75S21.75 12 21.75 12 18 18.75 12 18.75 2.25 12 2.25 12zm9.75-3a3 3 0 110 6 3 3 0 010-6z"/>
                      </svg>
                    </button>
                    <!-- Revoke all installs for user -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="revokeAllInstalls(u)"
                      :title="'Revoke all : Revoke all installations for this user'"
                      data-tip="Revoke all : Revoke all installations for this user"
                      aria-label="Revoke all installs for user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                    <!-- Ban & Revoke all installs -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip text-error"
                      @click="banAndRevoke(u)"
                      :title="'Ban & Revoke : Ban the user and revoke all installations'"
                      data-tip="Ban & Revoke : Ban the user and revoke all installations"
                      aria-label="Ban and revoke all installs"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 3a9 9 0 100 18 9 9 0 000-18zM8 8l8 8M16 8l-8 8"/>
                      </svg>
                    </button>
                    <!-- Copy user id -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="() => copyText(u.id)"
                      :title="'Copy ID : Copy this user\'s id'"
                      data-tip="Copy ID : Copy this user's id"
                      aria-label="Copy user id"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2M8 12h8a2 2 0 012 2v4a2 2 0 01-2 2H10a2 2 0 01-2-2v-4z"/>
                      </svg>
                    </button>
                    <!-- Copy email -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      :disabled="!u.email"
                      @click="() => copyText(u.email)"
                      :title="'Copy Email : Copy this user\'s email'"
                      data-tip="Copy Email : Copy this user's email"
                      aria-label="Copy user email"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 7l9 6 9-6M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                      </svg>
                    </button>
                    <!-- Ban / Unban -->
                    <button
                      v-if="!u.banned"
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="banUser(u)"
                      :title="'Ban : Prevent this user from accessing services'"
                      data-tip="Ban : Prevent this user from accessing services"
                      aria-label="Ban user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 3a9 9 0 100 18 9 9 0 000-18zm-6.364 9l12.728 0M8.464 8.464l7.072 7.072"/>
                      </svg>
                    </button>
                    <button
                      v-else
                      class="btn btn-ghost btn-xs btn-square tooltip text-success"
                      @click="unbanUser(u)"
                      :title="'Unban : Restore this user\'s access'"
                      data-tip="Unban : Restore this user's access"
                      aria-label="Unban user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m-3-7a9 9 0 110 18 9 9 0 010-18z"/>
                      </svg>
                    </button>
                    <!-- Delete user -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip text-error"
                      @click="deleteUser(u)"
                      :title="'Delete : Permanently delete this user (cannot be undone)'"
                      data-tip="Delete : Permanently delete this user (cannot be undone)"
                      aria-label="Delete user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 7h12M9 7v10m6-10v10M10 4h4a1 1 0 011 1v2H9V5a1 1 0 011-1zM7 7l1 12a2 2 0 002 2h4a2 2 0 002-2l1-12"/>
                      </svg>
                    </button>
                    <!-- Filter installations by this user -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="filterInstallsForUser(u)"
                      :title="'Filter installs : Filter installations table by this user'"
                      data-tip="Filter installs : Filter installations table by this user"
                      aria-label="Filter installations by user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 5h18M6 10h12M10 15h4"/>
                      </svg>
                    </button>
                  </td>
                </tr>
                <tr v-if="!usersPaged.length">
                  <td colspan="5" class="opacity-70">
                    <div class="flex items-center justify-between">
                      <span>No users match current filters</span>
                      <button class="btn btn-ghost btn-xs" @click="resetUsersFilters">Clear filters</button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="mt-2 flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <button class="btn btn-xs tooltip" :disabled="userPage===1" @click="userPage=userPage-1" :title="'Go to previous users page'" data-tip="Prev page">Prev</button>
              <span class="text-xs tooltip" :title="'Current users page'" data-tip="Page index">Page {{ userPage }}</span>
              <button class="btn btn-xs tooltip" :disabled="usersPaged.length < userPageSize" @click="userPage=userPage+1" :title="'Go to next users page'" data-tip="Next page">Next</button>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-xs opacity-70">Rows</span>
              <select id="users-page-size" name="users_page_size" class="select select-xxs select-bordered" v-model.number="userPageSize" aria-label="Users rows per page">
                <option :value="10">10</option>
                <option :value="25">25</option>
                <option :value="50">50</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Installations table -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 id="installations" class="card-title">Installations</h2>
            <div class="flex gap-2">
              <input id="installs-search" name="installs_search" class="input input-sm input-bordered tooltip" placeholder="Search install_id or user email" v-model="installQuery" :title="'Filter installations by id or user email'" aria-label="Search installations" data-tip="Filter installations"/>
              <button class="btn btn-outline btn-error btn-sm tooltip" @click="revokeFilteredInstalls" :disabled="busy || !installationsFiltered.length" :title="'Revoke all currently filtered installations (double confirm)'" data-tip="Revoke filtered">Revoke filtered</button>
              <button class="btn btn-outline btn-sm tooltip" @click="exportInstallsCsv" :disabled="busy || !installationsFiltered.length" :title="'Download visible installations as CSV'" data-tip="Export installations">Export CSV</button>
              <button class="btn btn-ghost btn-sm tooltip" @click="loadInstallations" :disabled="busy" :title="'Reload installations list from server'" data-tip="Reload installs">Refresh</button>
            </div>
          </div>
          <div class="overflow-x-auto mt-2">
            <table class="table admin-table table-sm w-full text-left">
              <colgroup>
                <col style="width: 16ch" />
                <col />
                <col style="width: 10ch" />
                <col style="width: 18ch" />
                <col style="width: 18ch" />
                <col />
              </colgroup>
              <thead>
                <tr class="whitespace-nowrap">
                  <th
                    class="px-2 col-id cursor-pointer select-none"
                    :title="'Unique installation id (seedling) for this user'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(installSortKey, 'install_id', installSortDir)"
                    @click="toggleInstallSort('install_id')"
                    @keydown.enter.prevent="toggleInstallSort('install_id')"
                    @keydown.space.prevent="toggleInstallSort('install_id')"
                  >
                    Install ID
                    <span class="ml-1 opacity-70" v-if="installSortKey==='install_id'">{{ installSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'Owning user (email if known); empty if unlinked'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(installSortKey, 'user', installSortDir)"
                    @click="toggleInstallSort('user')"
                    @keydown.enter.prevent="toggleInstallSort('user')"
                    @keydown.space.prevent="toggleInstallSort('user')"
                  >
                    User (email)
                    <span class="ml-1 opacity-70" v-if="installSortKey==='user'">{{ installSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'Active or revoked install state'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(installSortKey, 'status', installSortDir)"
                    @click="toggleInstallSort('status')"
                    @keydown.enter.prevent="toggleInstallSort('status')"
                    @keydown.space.prevent="toggleInstallSort('status')"
                  >
                    Status
                    <span class="ml-1 opacity-70" v-if="installSortKey==='status'">{{ installSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'When this installation was created'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(installSortKey, 'created_at', installSortDir)"
                    @click="toggleInstallSort('created_at')"
                    @keydown.enter.prevent="toggleInstallSort('created_at')"
                    @keydown.space.prevent="toggleInstallSort('created_at')"
                  >
                    Created
                    <span class="ml-1 opacity-70" v-if="installSortKey==='created_at'">{{ installSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th
                    class="cursor-pointer select-none"
                    :title="'Last activity time recorded for this installation'"
                    role="button" tabindex="0"
                    :aria-sort="ariaSort(installSortKey, 'last_seen', installSortDir)"
                    @click="toggleInstallSort('last_seen')"
                    @keydown.enter.prevent="toggleInstallSort('last_seen')"
                    @keydown.space.prevent="toggleInstallSort('last_seen')"
                  >
                    Last seen
                    <span class="ml-1 opacity-70" v-if="installSortKey==='last_seen'">{{ installSortDir==='asc' ? '▲' : '▼' }}</span>
                    <span class="ml-1 opacity-40" v-else>↕</span>
                  </th>
                  <th :title="'Available administrative actions for this installation'">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="s in installationsPaged" :key="s.install_id">
                  <td class="col-id font-mono text-xs whitespace-nowrap px-2" :title="s.install_id">{{ s.install_id }}</td>
                  <td class="font-mono text-xs break-words" :title="userEmail(s.user_id) || s.user_id || '—'">{{ userEmail(s.user_id) || s.user_id || '—' }}</td>
                  <td class="whitespace-nowrap">
                    <span v-if="String(s.status||'active')==='active'" class="badge badge-success badge-sm">active</span>
                    <span v-else class="badge badge-error badge-sm">{{ s.status }}</span>
                  </td>
                  <td class="whitespace-nowrap" :title="ts(s.created_at)">{{ ts(s.created_at) }}</td>
                  <td class="whitespace-nowrap" :title="ts(s.last_seen)">{{ ts(s.last_seen) }}</td>
                  <td class="flex flex-wrap items-center gap-1.5">
                    <!-- Rotate secret -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      :disabled="busy"
                      @click="rotateSecret(s.install_id)"
                      :title="'Rotate secret : Regenerate the seedling secret (sk) and issue a new manifest URL'"
                      data-tip="Rotate secret : Regenerate the seedling secret (sk) and issue a new manifest URL"
                      aria-label="Rotate secret"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992m0 0V4.356m0 4.992L14.1 16.26a5.25 5.25 0 11-7.425-7.425l3.9-3.9"/>
                      </svg>
                    </button>

                    <!-- Signed link -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      :disabled="busy"
                      @click="generateSignedManifest(s.install_id)"
                      :title="'Signed link : Create a short‑lived signed URL that redirects to the per-install manifest'"
                      data-tip="Signed link : Create a short‑lived signed URL that redirects to the per-install manifest"
                      aria-label="Signed link"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6h3.25A2.25 2.25 0 0119 8.25v7.5A2.25 2.25 0 0116.75 18H13.5m-3 0H7.25A2.25 2.25 0 015 15.75v-7.5A2.25 2.25 0 017.25 6H10.5m-3.75 6h10.5"/>
                      </svg>
                    </button>

                    <!-- Revoke -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      :disabled="busy || s.status==='revoked'"
                      @click="revoke(s.install_id)"
                      :title="'Revoke : Invalidate this installation; it will no longer be able to use its manifest'"
                      data-tip="Revoke : Invalidate this installation; it will no longer be able to use its manifest"
                      aria-label="Revoke install"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                      </svg>
                    </button>

                    <!-- Delete -->
                    <button
                      class="btn btn-ghost btn-xs btn-square text-error tooltip"
                      :disabled="busy"
                      @click="remove(s.install_id)"
                      :title="'Delete : Permanently delete this installation (cannot be undone)'"
                      data-tip="Delete : Permanently delete this installation (cannot be undone)"
                      aria-label="Delete install"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 7h12M9 7v10m6-10v10M10 4h4a1 1 0 011 1v2H9V5a1 1 0 011-1zM7 7l1 12a2 2 0 002 2h4a2 2 0 002-2l1-12"/>
                      </svg>
                    </button>

                    <!-- Start onboarding -->
                    <RouterLink
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      :to="`/start?sid=${encodeURIComponent(s.install_id)}`"
                      :title="'Onboard : Open onboarding with this install_id prefilled'"
                      data-tip="Onboard : Open onboarding with this install_id prefilled"
                      aria-label="Start onboarding"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14m-7-7l7 7-7 7"/>
                      </svg>
                    </RouterLink>

                    <!-- View manifest -->
                    <a
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      :href="globalManifestUrl"
                      target="_blank"
                      rel="noopener"
                      :title="'Manifest : Open the global manifest in a new tab'"
                      data-tip="Manifest : Open the global manifest in a new tab"
                      aria-label="Open manifest"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m6-6H6"/>
                      </svg>
                    </a>

                    <!-- Copy manifest URL -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="copyGlobalManifest"
                      :title="'Copy URL : Copy the global manifest URL'"
                      data-tip="Copy URL : Copy the global manifest URL"
                      aria-label="Copy manifest URL"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2M8 12h8a2 2 0 012 2v4a2 2 0 01-2 2H10a2 2 0 01-2-2v-4z"/>
                      </svg>
                    </button>

                    <!-- Copy stremio link -->
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="copyGlobalStremio"
                      :title="'Copy Stremio : Copy the global stremio:// link'"
                      data-tip="Copy Stremio : Copy the global stremio:// link"
                      aria-label="Copy stremio link"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H16a4 4 0 010 8h-2.5m-3 0H8a4 4 0 010-8h2.5m1 4H12"/>
                      </svg>
                    </button>
                  </td>
                </tr>
                <tr v-if="!installationsPaged.length">
                  <td colspan="6" class="opacity-70">No installations</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="mt-2 flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <button class="btn btn-xs tooltip" :disabled="installPage===1" @click="installPage=installPage-1" :title="'Go to previous installations page'" data-tip="Prev page">Prev</button>
              <span class="text-xs tooltip" :title="'Current installations page'" data-tip="Page index">Page {{ installPage }}</span>
              <button class="btn btn-xs tooltip" :disabled="installationsPaged.length < installPageSize" @click="installPage=installPage+1" :title="'Go to next installations page'" data-tip="Next page">Next</button>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-xs opacity-70">Rows</span>
              <select id="installs-page-size" name="installs_page_size" class="select select-xxs select-bordered" v-model.number="installPageSize" aria-label="Installations rows per page">
                <option :value="10">10</option>
                <option :value="25">25</option>
                <option :value="50">50</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Charts (Users/Installs Daily) -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title tooltip" :title="'Daily counts for users and installations over the selected time window'" data-tip="Daily metrics">Metrics (last {{ metricsDays }} days)</h2>
            <div class="flex gap-2">
              <select class="select select-sm select-bordered" v-model.number="metricsDays" @change="loadMetrics">
                <option :value="7">7</option>
                <option :value="30">30</option>
                <option :value="60">60</option>
                <option :value="90">90</option>
              </select>
              <button class="btn btn-ghost btn-sm" @click="loadMetrics" :disabled="busy">Reload</button>
            </div>
          </div>
          <div class="grid md:grid-cols-2 gap-4">
            <div>
              <div class="opacity-80 text-sm mb-1">Users / day</div>
              <svg :width="chartW" :height="chartH">
                <path :d="sparklinePath((metrics && metrics.users) ? metrics.users : [])" stroke="currentColor" fill="none" stroke-width="2" />
              </svg>
            </div>
            <div>
              <div class="opacity-80 text-sm mb-1">Installations / day</div>
              <svg :width="chartW" :height="chartH">
                <path :d="sparklinePath((metrics && metrics.installs) ? metrics.installs : [])" stroke="currentColor" fill="none" stroke-width="2" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- Audit viewer -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Audit Log</h2>
            <div class="flex gap-2"></div>
          </div>
          <table class="table table-sm">
            <thead><tr><th>ID</th><th>Event</th><th>At</th><th>Meta</th></tr></thead>
            <tbody>
              <tr v-for="a in audit" :key="a.id">
                <td class="font-mono text-xs">{{ a.id }}</td>
                <td>{{ a.event }}</td>
                <td>{{ ts(a.at) }}</td>
                <td>
                  <details>
                    <summary class="cursor-pointer text-xs opacity-70">view</summary>
                    <pre class="text-xs overflow-x-auto">{{ formatMeta(a.meta_json) }}</pre>
                  </details>
                </td>
              </tr>
              <tr v-if="!audit.length"><td colspan="4" class="opacity-70">No audit entries</td></tr>
            </tbody>
          </table>
          <div class="mt-2 flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <button class="btn btn-xs" @click="prevAudit" :disabled="auditOffset<=0">Prev</button>
              <span class="text-xs">Page {{ auditPage }}</span>
              <button class="btn btn-xs" @click="nextAudit">Next</button>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-xs opacity-70">Rows</span>
              <select id="audit-page-size" name="audit_page_size" class="select select-xxs select-bordered" v-model.number="auditLimit" aria-label="Audit rows per page">
                <option :value="50">50</option>
                <option :value="100">100</option>
                <option :value="200">200</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Bans summary and list (admin only) -->
      <div class="card bg-base-200" v-if="isAuthed && isAllowed">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Moderation</h2>
            <div class="flex items-center gap-3">
              <div>
                <div class="text-sm opacity-70">Banned users</div>
                <div class="text-xl font-semibold">{{ bansCount }}</div>
              </div>
              <button class="btn btn-ghost btn-sm tooltip" @click="openBans" :title="'Open current bans list'" data-tip="Open bans">View</button>
              <button class="btn btn-ghost btn-sm tooltip" @click="loadBans" :disabled="busy" :title="'Reload bans list from server'" data-tip="Reload bans">Reload</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Bans modal -->
      <dialog ref="bansDlg" class="modal">
        <div class="modal-box max-w-xl">
          <h3 class="font-bold text-lg">Banned Users</h3>
          <p class="text-sm opacity-70 mb-2">Total: {{ bansCount }}</p>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr><th>User ID</th><th>Reason</th><th>Since</th><th>Actions</th></tr>
              </thead>
              <tbody>
                <tr v-for="b in bans" :key="b.user_id">
                  <td class="font-mono text-xs">{{ b.user_id }}</td>
                  <td class="text-xs">{{ b.reason || '—' }}</td>
                  <td class="whitespace-nowrap text-xs">{{ ts(b.created_at) }}</td>
                  <td class="whitespace-nowrap">
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="unbanFromBans(b)"
                      :title="'Unban : Restore this user\'s access'"
                      data-tip="Unban : Restore this user's access"
                      aria-label="Unban user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m-3-7a9 9 0 110 18 9 9 0 010-18z"/>
                      </svg>
                    </button>
                    <button
                      class="btn btn-ghost btn-xs btn-square tooltip"
                      @click="revokeAllFromBans(b)"
                      :title="'Revoke all : Revoke all installations for this user'"
                      data-tip="Revoke all : Revoke all installations for this user"
                      aria-label="Revoke all installs for user"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                  </td>
                </tr>
                <tr v-if="!bans.length"><td colspan="4" class="opacity-70">No bans</td></tr>
              </tbody>
            </table>
          </div>
          <div class="modal-action">
            <button class="btn" @click="closeBans">Close</button>
          </div>
        </div>
      </dialog>

    </div>
  </main>
    <!-- User drawer -->
    <dialog ref="userDlg" class="modal">
      <div class="modal-box max-w-3xl">
        <div class="flex items-start justify-between gap-3">
          <div>
            <h3 class="font-bold text-lg">User details</h3>
            <p class="text-sm opacity-80">
              {{ activeUser?.email || '—' }} ({{ activeUser?.id || '—' }})

// Gardeners management (script)
const gardeners = ref([])
const gardenerQuery = ref('')
const gardenerLimit = ref(50)
const gardenerOffset = ref(0)
const gardenerPage = computed(() => {
  try { const size = Math.max(1, Number(gardenerLimit.value)||1); const off = Math.max(0, Number(gardenerOffset.value)||0); return Math.floor(off/size)+1 } catch { return 1 }
})
const gardenerDetails = ref(null)
const gardenerDlg = ref(null)
const gardenerAssignUserId = ref('')
const selectedGardeners = ref(new Set())
const allGardenersSelected = computed(() => {
  try { return gardenersFiltered.value.length > 0 && gardenersFiltered.value.every(g => selectedGardeners.value.has(g.gardener_id)) } catch { return false }
})
function toggleSelectOne(id, ev) {
  try {
    if (ev && ev.target && ev.target.checked) selectedGardeners.value.add(id)
    else selectedGardeners.value.delete(id)
  } catch (_) {}
}
function toggleSelectAll(ev) {
  try {
    const checked = !!(ev && ev.target && ev.target.checked)
    if (checked) { for (const g of gardenersFiltered.value) selectedGardeners.value.add(g.gardener_id) }
    else { selectedGardeners.value.clear() }
  } catch (_) {}
}
async function bulkUnlinkAll() {
  if (selectedGardeners.value.size === 0) return
  if (!confirm(`Unlink all bindings for ${selectedGardeners.value.size} gardeners?`)) return
  busy.value = true
  try {
    for (const gid of Array.from(selectedGardeners.value)) {
      try { await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}/bindings`, { method: 'DELETE', credentials: 'include' }) } catch (_) {}
    }
    showToast('Bulk unlink triggered', 'success')
    await loadGardeners(true)
  } catch (_) { showToast('Bulk unlink failed', 'error') } finally { busy.value = false }
}
async function bulkDeleteGardeners() {
  if (selectedGardeners.value.size === 0) return
  if (!confirm(`Delete ${selectedGardeners.value.size} gardeners and their bindings? This cannot be undone.`)) return
  busy.value = true
  try {
    for (const gid of Array.from(selectedGardeners.value)) {
      try { await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}`, { method: 'DELETE', credentials: 'include' }) } catch (_) {}
    }
    showToast('Bulk delete triggered', 'success')
    selectedGardeners.value.clear()
    await loadGardeners(true)
  } catch (_) { showToast('Bulk delete failed', 'error') } finally { busy.value = false }
}
const gardenerHasBindingsOnly = ref(false)
const gardenerStaleOnly = ref(false)
const gardenerStaleMinutes = ref(60)
const gardenersFiltered = computed(() => {
  try {
    const base = Array.isArray(gardeners.value) ? gardeners.value : []
    const ms = Math.max(1, Number(gardenerStaleMinutes.value)||60) * 60_000
    const now = Date.now()
    return base.filter(g => {
      if (gardenerHasBindingsOnly.value && !(Number(g.bindings_count||0) > 0)) return false
      if (gardenerStaleOnly.value) {
        const last = Number(g.last_seen || 0)
        if (!(last > 0) || (now - last) < ms) return false
      }
      return true
    })
  } catch (_) { return gardeners.value || [] }
})

// Persist gardener table preferences
const LS_GARDENERS_PREFS = 'admin_gardeners_prefs'
function saveGardenersPrefs() {
  try {
    const obj = {
      q: gardenerQuery.value,
      hb: !!gardenerHasBindingsOnly.value,
      st: !!gardenerStaleOnly.value,
      sm: Number(gardenerStaleMinutes.value)||60,
      lim: Number(gardenerLimit.value)||50,
    }
    localStorage.setItem(LS_GARDENERS_PREFS, JSON.stringify(obj))
  } catch (_) {}
}
function loadGardenersPrefs() {
  try {
    const raw = localStorage.getItem(LS_GARDENERS_PREFS)
    if (!raw) return
    const obj = JSON.parse(raw)
    if (obj && typeof obj === 'object') {
      if (typeof obj.q === 'string') gardenerQuery.value = obj.q
      if (typeof obj.hb === 'boolean') gardenerHasBindingsOnly.value = obj.hb
      if (typeof obj.st === 'boolean') gardenerStaleOnly.value = obj.st
      if (Number.isFinite(obj.sm)) gardenerStaleMinutes.value = obj.sm
      if (Number.isFinite(obj.lim)) gardenerLimit.value = obj.lim
    }
  } catch (_) {}
}
watch([gardenerQuery, gardenerHasBindingsOnly, gardenerStaleOnly, gardenerStaleMinutes, gardenerLimit], () => { try { saveGardenersPrefs() } catch (_) {} })

async function loadGardeners(force = false) {
  try {
    busy.value = true
    const params = new URLSearchParams()
    if (gardenerQuery.value) params.set('query', gardenerQuery.value)
    params.set('limit', String(gardenerLimit.value))
    params.set('offset', String(gardenerOffset.value))
    const res = await fetch(`/api/admin/gardeners?${params.toString()}`, { credentials: 'include', cache: force ? 'no-store' : 'default' })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'load_failed')
    gardeners.value = Array.isArray(j.gardeners) ? j.gardeners : []
  } catch (e) {
    toastType.value = 'alert-error'
    toastMsg.value = 'Failed to load gardeners'
  } finally { busy.value = false }
}

const gardenerHealth = ref(null)

// Stale presets
function applyStalePreset(ev) {
  try { const v = Number(ev && ev.target && ev.target.value); if (Number.isFinite(v) && v > 0) gardenerStaleMinutes.value = v } catch (_) {}
}

// Reassign binding modal
const reassignDlg = ref(null)
const reassignSeedlingId = ref('')
const reassignTargetId = ref('')
const gardenerSuggestions = computed(() => {
  try {
    const cur = gardenerDetails.value?.gardener_id || ''
    // Suggest recent gardeners by last_seen (excluding current)
    return [...(gardeners.value||[])]
      .filter(g => g.gardener_id !== cur)
      .sort((a,b) => (Number(b.last_seen||0) - Number(a.last_seen||0)))
      .slice(0, 8)
  } catch (_) { return [] }
})
function openReassign(seedling_id) {
  reassignSeedlingId.value = seedling_id || ''
  reassignTargetId.value = ''
  try { reassignDlg.value?.showModal && reassignDlg.value.showModal() } catch (_) {}
}
async function confirmReassign() {
  try {
    if (!gardenerDetails.value || !reassignSeedlingId.value || !reassignTargetId.value) return
    busy.value = true
    const fromId = gardenerDetails.value.gardener_id
    const toId = reassignTargetId.value.trim()
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(fromId)}/bindings/${encodeURIComponent(reassignSeedlingId.value)}/reassign`, {
      method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ to_gardener_id: toId })
    })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'reassign_failed')
    toastType.value = 'alert-success'; toastMsg.value = 'Binding moved'
    try { reassignDlg.value?.close && reassignDlg.value.close() } catch (_) {}
    await openGardener({ gardener_id: fromId })
    await loadGardeners(true)
  } catch (e) { toastType.value = 'alert-error'; toastMsg.value = 'Failed to move binding' } finally { busy.value = false }
}
function prevGardeners() { gardenerOffset.value = Math.max(0, gardenerOffset.value - gardenerLimit.value); loadGardeners() }
function nextGardeners() { gardenerOffset.value = gardenerOffset.value + gardenerLimit.value; loadGardeners() }
watch(gardenerLimit, () => { try { gardenerOffset.value = 0; loadGardeners(true) } catch (_) {} })

async function openGardener(g) {
  try {
    busy.value = true
    gardenerDetails.value = null
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(g.gardener_id)}`, { credentials: 'include', cache: 'no-store' })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'load_failed')
    gardenerDetails.value = j.gardener
    // Load health snapshot
    try {
      const h = await fetch(`/api/admin/gardeners/${encodeURIComponent(g.gardener_id)}/health`, { credentials: 'include', cache: 'no-store' })
      const hj = await h.json(); gardenerHealth.value = (h.ok && hj && hj.ok) ? (hj.health || null) : null
    } catch (_) { gardenerHealth.value = null }
    try { gardenerDlg.value?.showModal && gardenerDlg.value.showModal() } catch (_) {}
  } catch (e) {
    toastType.value = 'alert-error'
    toastMsg.value = 'Failed to load gardener details'
  } finally { busy.value = false }
}

async function unlinkBinding(seedling_id) {
  try {
    if (!gardenerDetails.value) return
    busy.value = true
    const gid = gardenerDetails.value.gardener_id
    const res = await fetch(`/api/admin/gardeners/${encodeURIComponent(gid)}/bindings/${encodeURIComponent(seedling_id)}`, { method: 'DELETE', credentials: 'include' })
    const j = await res.json()
    if (!res.ok || !j || j.ok === false) throw new Error(j && j.error || 'unlink_failed')
    toastType.value = 'alert-success'
    toastMsg.value = 'Binding unlinked'
    await openGardener({ gardener_id: gid })
    await loadGardeners(true)
  } catch (e) {
    toastType.value = 'alert-error'
    toastMsg.value = 'Failed to unlink binding'
  } finally { busy.value = false }
}

function exportGardenersCsv() {
  const data = (gardenersFiltered.value||[]).map(g => ({ gardener_id: g.gardener_id, user_id: g.user_id, platform: g.platform, created_at: g.created_at, last_seen: g.last_seen, bindings: g.bindings_count }))
  downloadText('gardeners.csv', toCsv(data, ['gardener_id','user_id','platform','created_at','last_seen','bindings']))
}
async function copyGardenersCsv() {
  try {
    const data = (gardenersFiltered.value||[]).map(g => ({ gardener_id: g.gardener_id, user_id: g.user_id, platform: g.platform, created_at: g.created_at, last_seen: g.last_seen, bindings: g.bindings_count }))
    const csv = toCsv(data, ['gardener_id','user_id','platform','created_at','last_seen','bindings'])
    await navigator.clipboard.writeText(csv)
    showToast('Gardeners CSV copied', 'success')
  } catch (_) { showToast('Copy failed', 'error') }
}
function exportBindingsCsv() {
  const list = (gardenerDetails.value && gardenerDetails.value.bindings) ? gardenerDetails.value.bindings : []
  const data = list.map(b => ({ gardener_id: gardenerDetails.value?.gardener_id || '', seedling_id: b.seedling_id, created_at: b.created_at }))
  downloadText(`bindings-${gardenerDetails.value?.gardener_id||'gardener'}.csv`, toCsv(data, ['gardener_id','seedling_id','created_at']))
}
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-1.5">
            <button class="btn btn-ghost btn-xs btn-square tooltip" :disabled="!activeUser?.id" @click="() => copyText(activeUser?.id)" :title="'Copy ID : Copy this user\'s id'" data-tip="Copy ID : Copy this user's id" aria-label="Copy user id">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2M8 12h8a2 2 0 012 2v4a2 2 0 01-2 2H10a2 2 0 01-2-2v-4z"/></svg>
            </button>
            <button class="btn btn-ghost btn-xs btn-square tooltip" :disabled="!activeUser?.email" @click="() => copyText(activeUser?.email || '')" :title="'Copy Email : Copy this user\'s email'" data-tip="Copy Email : Copy this user's email" aria-label="Copy user email">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M3 7l9 6 9-6M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
            </button>
            <button class="btn btn-ghost btn-xs btn-square tooltip" :disabled="!activeUser?.id" @click="revokeAllInstalls(activeUser)" :title="'Revoke all : Revoke all installations for this user'" data-tip="Revoke all : Revoke all installations for this user" aria-label="Revoke all installs for user">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
            <button class="btn btn-ghost btn-xs btn-square tooltip text-error" :disabled="!activeUser?.id" @click="banAndRevoke(activeUser)" :title="'Ban & Revoke : Ban the user and revoke all installations'" data-tip="Ban & Revoke : Ban the user and revoke all installations" aria-label="Ban and revoke all installs">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3a9 9 0 100 18 9 9 0 000-18zM8 8l8 8M16 8l-8 8"/></svg>
            </button>
            <button v-if="activeUser && !activeUser.banned" class="btn btn-ghost btn-xs btn-square tooltip" :disabled="!activeUser?.id" @click="banUser(activeUser)" :title="'Ban : Prevent this user\'s access'" data-tip="Ban : Prevent this user's access" aria-label="Ban user">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3a9 9 0 100 18 9 9 0 000-18zm-6.364 9l12.728 0M8.464 8.464l7.072 7.072"/></svg>
            </button>
            <button v-else class="btn btn-ghost btn-xs btn-square tooltip text-success" :disabled="!activeUser?.id" @click="unbanUser(activeUser)" :title="'Unban : Restore access'" data-tip="Unban : Restore access" aria-label="Unban user">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m-3-7a9 9 0 110 18 9 9 0 010-18z"/></svg>
            </button>
            <button class="btn btn-ghost btn-xs btn-square tooltip text-error" :disabled="!activeUser?.id" @click="deleteUser(activeUser)" :title="'Delete : Permanently delete this user'" data-tip="Delete : Permanently delete this user" aria-label="Delete user">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M6 7h12M9 7v10m6-10v10M10 4h4a1 1 0 011 1v2H9V5a1 1 0 011-1zM7 7l1 12a2 2 0 002 2h4a2 2 0 002-2l1-12"/></svg>
            </button>
            <button class="btn btn-ghost btn-xs btn-square tooltip" :disabled="!activeUser?.id" @click="filterInstallsForUser(activeUser)" :title="'Filter installs : Filter installations table by this user'" data-tip="Filter installs : Filter installations table by this user" aria-label="Filter installations by user">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M3 5h18M6 10h12M10 15h4"/></svg>
            </button>
          </div>
        </div>
        <div class="divider"></div>
        <h4 class="font-semibold mb-2">User's seedlings</h4>
        <div class="overflow-x-auto max-h-80">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Install ID</th>
                <th>Status</th>
                <th>Created</th>
                <th>Last seen</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in userSeedlings" :key="s.install_id">
                <td class="font-mono text-xs break-all">{{ s.install_id }}</td>
                <td>{{ s.status }}</td>
                <td>{{ ts(s.created_at) }}</td>
                <td>{{ ts(s.last_seen) }}</td>
              </tr>
              <tr v-if="!userSeedlings.length"><td colspan="4" class="opacity-70">No seedlings</td></tr>
            </tbody>
          </table>
        </div>
        <div class="modal-action">
          <form method="dialog">
            <button class="btn">Close</button>
          </form>
        </div>
      </div>
    </dialog>

    <!-- Gardener details dialog -->
    <dialog ref="gardenerDlg" class="modal">
      <div class="modal-box max-w-3xl">
        <div class="flex items-start justify-between gap-3">
          <div>
            <h3 class="font-bold text-lg">Gardener details</h3>
            <p class="text-sm opacity-80">
              <span class="font-mono">{{ gardenerDetails?.gardener_id || '—' }}</span>
              <span class="mx-2">·</span>
              user: <span class="font-mono">{{ gardenerDetails?.user_id || '—' }}</span>
              <span class="mx-2">·</span>
              platform: {{ gardenerDetails?.platform || '—' }}
            </p>
            <p class="text-xs opacity-70 mt-1">Created: {{ ts(gardenerDetails?.created_at) }} · Last seen: {{ ts(gardenerDetails?.last_seen) }}</p>
          </div>
          <div class="flex flex-wrap items-center gap-1.5">
            <button class="btn btn-ghost btn-xs btn-square tooltip" :disabled="!gardenerDetails?.gardener_id" @click="() => copyText(gardenerDetails?.gardener_id||'')" :title="'Copy gardener id'" data-tip="Copy gardener id" aria-label="Copy gardener id">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2M8 12h8a2 2 0 012 2v4a2 2 0 01-2 2H10a2 2 0 01-2-2v-4z"/></svg>
            </button>
            <button class="btn btn-ghost btn-xs tooltip" @click="() => openGardener({ gardener_id: gardenerDetails?.gardener_id })" :disabled="!gardenerDetails?.gardener_id" :title="'Refresh details'" data-tip="Refresh details">Refresh</button>
            <button class="btn btn-outline btn-xs tooltip" @click="exportBindingsCsv" :disabled="!gardenerDetails || !gardenerDetails.bindings?.length" :title="'Export bindings as CSV'" data-tip="Export bindings">Export CSV</button>
            <RouterLink class="btn btn-ghost btn-xs tooltip" v-if="gardenerDetails?.gardener_id" :to="`/activity?gid=${encodeURIComponent(gardenerDetails.gardener_id)}`" :title="'Open Activity scoped to this gardener'" data-tip="View Activity">View Activity</RouterLink>
          </div>
        </div>
        <div class="mt-3 flex flex-wrap items-end gap-2 bg-base-300/30 rounded-box p-2">
          <label class="form-control">
            <span class="label-text text-xs">Assign user id</span>
            <input type="text" class="input input-sm input-bordered w-64" v-model="gardenerAssignUserId" placeholder="user id (provider:id)" />
          </label>
          <button class="btn btn-sm" :disabled="busy || !gardenerDetails?.gardener_id || !gardenerAssignUserId" @click="assignGardenerUser">Assign</button>
          <button class="btn btn-ghost btn-sm" :disabled="busy || !gardenerDetails?.gardener_id" @click="clearGardenerUser">Clear user</button>
          <span class="mx-2 opacity-40">|</span>
          <button class="btn btn-outline btn-sm" :disabled="busy || !gardenerDetails?.gardener_id" @click="unlinkAllBindings">Unlink all bindings</button>
          <button class="btn btn-error btn-sm" :disabled="busy || !gardenerDetails?.gardener_id" @click="deleteGardener">Delete gardener</button>
        </div>
        <div class="divider"></div>
        <div class="p-2 rounded-box bg-base-300/30 mb-2" v-if="gardenerHealth">
          <div class="font-semibold text-sm mb-1">Health (live)</div>
          <div class="text-xs grid grid-cols-2 gap-2">
            <div>Queue: {{ gardenerHealth.queue }}</div>
            <div>Success 1m: {{ gardenerHealth.s1m }}</div>
            <div>Fail 1m: {{ gardenerHealth.f1m }}</div>
            <div>Score: {{ gardenerHealth.score }}</div>
            <div class="opacity-70">Updated: {{ ts(gardenerHealth.ts) }}</div>
          </div>
        </div>
        <h4 class="font-semibold mb-2">Bindings ({{ gardenerDetails?.bindings?.length || 0 }})</h4>
        <div class="overflow-x-auto max-h-80">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Seedling ID</th>
                <th>Linked at</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="b in (gardenerDetails?.bindings||[])" :key="b.seedling_id">
                <td class="font-mono text-xs break-all">{{ b.seedling_id }}</td>
                <td class="whitespace-nowrap">{{ ts(b.created_at) }}</td>
                <td class="flex gap-1 flex-wrap">
                  <button class="btn btn-ghost btn-xxs tooltip" @click="() => copyText(b.seedling_id)" :title="'Copy seedling id'" data-tip="Copy seedling id">Copy</button>
                  <RouterLink class="btn btn-ghost btn-xxs tooltip" :to="`/configure?seedling_id=${encodeURIComponent(b.seedling_id)}`" target="_blank" rel="noopener" :title="'Open Configure for this seedling in a new tab'" data-tip="Open Configure">Configure</RouterLink>
                  <button class="btn btn-outline btn-xxs tooltip text-error" @click="unlinkBinding(b.seedling_id)" :title="'Unlink this binding'" data-tip="Unlink binding">Unlink</button>
                  <button class="btn btn-outline btn-xxs tooltip" @click="() => openReassign(b.seedling_id)" :title="'Move this binding to another gardener id'" data-tip="Reassign binding">Move</button>
                </td>
              </tr>
              <tr v-if="!gardenerDetails || !gardenerDetails.bindings || !gardenerDetails.bindings.length"><td colspan="3" class="opacity-70">No bindings</td></tr>
            </tbody>
          </table>
        </div>
        <div class="modal-action">
          <form method="dialog">
            <button class="btn">Close</button>
          </form>
        </div>
      </div>
    </dialog>
  </template>

<script setup>
import { ref, onMounted, computed, onBeforeUnmount, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { auth } from '../lib/auth'

const error = ref('')
const busy = ref(false)
// Toasts
const toastMsg = ref('')
const toastType = ref('alert-info')
function showToast(msg, type = 'info', ms = 2000) {
  toastMsg.value = msg
  toastType.value = type === 'success' ? 'alert-success' : (type === 'error' ? 'alert-error' : 'alert-info')
  setTimeout(() => { toastMsg.value = '' }, ms)
}
const summary = ref({ counts: {} })
const users = ref([])
const installations = ref([])
const magicEmail = ref('')
const userQuery = ref('')
const userPage = ref(1)
const userPageSize = ref(25)
const userOnlyBanned = ref(false)
const userProviderFilter = ref('all')
const userHasEmailOnly = ref(false)
const installQuery = ref('')
const installPage = ref(1)
const installPageSize = ref(25)
// Overview: scoped SSE seedling id
const scopeSeedlingId = ref('')

// Settings
const settings = ref({
  probe_providers: 'off',
  probe_timeout_ms: 500,
  provider_fetch_timeout_ms: 3000,
  swarm_enabled: 'off', swarm_top_n: 2, swarm_timeout_ms: 800, swarm_missing_only: 'on',
  sort_order: 'desc', sort_fields: 'resolution,peers,language',
  ai_enabled: 'off', ai_provider: 'openai', ai_model: 'gpt-4o', ai_timeout_ms: 2500, ai_cache_ttl_ms: 60000,
  telemetry_sample: 1,
  kofi_overlay: 'on',
  max_seedlings_per_user: 20,
})

const isAuthed = computed(() => !!auth.state.user)
const userLabel = computed(() => auth.parseUserLabel(auth.state.user))
const isAllowed = computed(() => {
  const email = (auth.state.user && auth.state.user.email) ? String(auth.state.user.email).toLowerCase() : ''
  return email === 'joseeduardox@gmail.com'
})

function ts(v) { try { if (!v) return '—'; return new Date(Number(v)).toLocaleString() } catch { return '—' } }

// Errors summary (metrics)
const errorsMinutes = ref(60)
const auditSummary = ref({})
async function loadErrorsSummary() {
  try {
    const r = await fetch(`/api/admin/metrics/errors?minutes=${errorsMinutes.value}`, { credentials: 'include' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('errors_summary_failed')
    auditSummary.value = j.summary || {}
  } catch (_) { auditSummary.value = {} }
}

// Fallback reasons summary
const fallbackMinutes = ref(60)
const fallbackSummary = ref({})
async function loadFallbackSummary() {
  try {
    const r = await fetch(`/api/admin/metrics/fallbacks?minutes=${fallbackMinutes.value}`, { credentials: 'include' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('fallback_summary_failed')
    fallbackSummary.value = j.reasons || {}
  } catch (_) { fallbackSummary.value = {} }
}

function copyText(t) { try { navigator.clipboard.writeText(String(t||'')) ; showToast('Copied', 'success') } catch (_) { showToast('Copy failed', 'error') } }

// Overview SSE + providers probe
let esBoosts = null
const sseStatus = ref('waiting') // waiting | ok | error
const sseStatusClass = computed(() => sseStatus.value === 'ok' ? 'text-success' : (sseStatus.value === 'error' ? 'text-error' : 'text-warning'))
const serverVersion = ref('')
const lastBoostTs = ref(0)
const lastPingTs = ref(0)
const sseClients = ref(1)
const boostsWindow = ref([]) // array of timestamps
const boostsPerMin = computed(() => {
  try {
    const now = Date.now()
    return boostsWindow.value.filter(ts => now - ts <= 60_000).length
  } catch { return 0 }
})
function connectBoostsSse_initial() { try { connectBoostsSse('') } catch (_) {} }
function ago(ts) { try { if (!ts) return '—'; const d = Math.max(0, Date.now()-ts); if (d<1000) return 'just now'; if (d<60_000) return Math.floor(d/1000)+'s'; if (d<3600_000) return Math.floor(d/60_000)+'m'; return Math.floor(d/3600_000)+'h' } catch { return '—' } }
const providersOk = ref(0)
const providersTotal = ref(0)
const providersAvgMs = ref(0)
const providersDetails = ref([])
// Boosts/min history bins for last hour
const bpmHistory = ref([])
const boostsHourBins = computed(() => {
  try {
    const now = Date.now()
    // Bin boostsWindow timestamps into 60 one-minute bins
    const bins = new Array(60).fill(0)
    for (const ts of boostsWindow.value) {
      const deltaMin = Math.floor((now - ts) / 60_000)
      if (deltaMin >= 0 && deltaMin < 60) bins[59 - deltaMin] += 1
    }
    return bins
  } catch (_) { return [] }
})
function heatColor(v) {
  const n = Number(v) || 0
  const level = Math.min(1, n / 5)
  const g = Math.floor(200 * (1 - level))
  const b = Math.floor(200 * (1 - level))
  return `rgb(0, ${g}, ${b})`
}
async function probeProviders() {
  busy.value = true
  try {
    const r = await fetch('/api/providers/detect', { credentials: 'include' })
    if (!r.ok) throw new Error('providers_failed')
    const j = await r.json()
    const list = Array.isArray(j.providers) ? j.providers : []
    providersTotal.value = list.length
    const oks = list.filter(p => p && p.ok)
    providersOk.value = oks.length
    const avg = list.length ? Math.round(list.reduce((a,b)=>a+(Number(b.ms)||0),0)/list.length) : 0
    providersAvgMs.value = avg
    providersDetails.value = list.map(p => ({ name: p.name || 'Provider', ok: !!p.ok, ms: Number(p.ms)||0 }))
    showToast('Providers probed', 'success')
  } catch (_) { showToast('Providers probe failed', 'error') } finally { busy.value = false }
}

// Scoped SSE with backoff
let sseRetryMs = 1000
function disconnectBoostsSse() { try { esBoosts && esBoosts.close() } catch (_) {} esBoosts = null; sseStatus.value = 'error' }
function connectBoostsSse(seedlingId = '') {
  try {
    sseStatus.value = 'waiting'
    if (esBoosts) { try { esBoosts.close() } catch (_) {} esBoosts = null }
    const url = (seedlingId && seedlingId.trim()) ? `/api/seedlings/${encodeURIComponent(seedlingId.trim())}/events` : '/api/boosts/events'
    esBoosts = new EventSource(url)
    esBoosts.onopen = () => { sseStatus.value = 'ok'; sseRetryMs = 1000 }
    esBoosts.addEventListener('server-info', (e) => { try { const d = JSON.parse(e.data); if (d && d.version) serverVersion.value = d.version } catch (_) {} })
    esBoosts.addEventListener('ping', (e) => { lastPingTs.value = Date.now() })
    esBoosts.addEventListener('boost', (e) => { const now = Date.now(); lastBoostTs.value = now; boostsWindow.value = [...boostsWindow.value, now] })
    esBoosts.addEventListener('snapshot', (e) => { try { const d = JSON.parse(e.data); const now = Date.now(); const n = Array.isArray(d.items) ? d.items.length : 0; if (n > 0) { lastBoostTs.value = now; boostsWindow.value = [...boostsWindow.value, now] } } catch (_) {} })
    esBoosts.onerror = () => { sseStatus.value = 'error'; try { esBoosts && esBoosts.close() } catch (_) {}; esBoosts = null; setTimeout(() => connectBoostsSse(seedlingId), Math.min(30000, sseRetryMs)); sseRetryMs = Math.min(30000, sseRetryMs * 2) }
  } catch (_) { sseStatus.value = 'error' }
}

function loginGoogle() { auth.loginWith('google') }
async function startMagic() {
  const ok = await auth.startMagic(String(magicEmail.value || '').trim())
  if (ok) {
    showToast('Check your email for the Magic Link.', 'success')
  }
}

// Admin: ban / unban / delete users
async function banUser(u) {
  try {
    const user_id = u && u.id
    if (!user_id) return
    // Double confirmation: explicit confirm plus optional reason
    if (typeof window !== 'undefined') {
      const ok = confirm(`Ban user ${u.email || user_id}?`)
      if (!ok) return
    }
    const reason = (typeof window !== 'undefined') ? (prompt('Ban reason (optional):') || '') : ''
    busy.value = true
    const r = await fetch(`/api/admin/users/${encodeURIComponent(user_id)}/ban`, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason }),
    })
    if (!r.ok) throw new Error('ban_failed')
    await loadUsers()
    await loadBans()
    showToast('User banned', 'success')
  } catch (_) { showToast('Ban failed', 'error') } finally { busy.value = false }
}

async function unbanUser(u) {
  try {
    const user_id = u && u.id
    if (!user_id) return
    busy.value = true
    const r = await fetch(`/api/admin/users/${encodeURIComponent(user_id)}/ban`, {
      method: 'DELETE',
      credentials: 'include',
    })
    if (!r.ok) throw new Error('unban_failed')
    await loadUsers()
    await loadBans()
    showToast('User unbanned', 'success')
  } catch (_) { showToast('Unban failed', 'error') } finally { busy.value = false }
}

async function deleteUser(u) {
  try {
    const user_id = u && u.id
    if (!user_id) return
    const label = u && (u.email || u.id)
    if (typeof window !== 'undefined') {
      const ok = confirm(`Delete user ${label}? This cannot be undone.`)
      if (!ok) return
      const typed = prompt(`Type the user id to confirm delete: ${user_id}`)
      if ((typed || '').trim() !== user_id) { showToast('Delete cancelled', 'error'); return }
    }
    busy.value = true
    const r = await fetch(`/api/admin/users/${encodeURIComponent(user_id)}`, {
      method: 'DELETE',
      credentials: 'include',
    })
    if (!r.ok) throw new Error('delete_failed')
    await loadUsers()
    await loadBans()
    showToast('User deleted', 'success')
  } catch (_) { showToast('Delete failed', 'error') } finally { busy.value = false }
}
async function logout() { try { await auth.logout() } catch (_) {} }

// Admin: batch revoke all currently filtered installations
async function revokeFilteredInstalls() {
  try {
    const ids = installationsFiltered.value.map(i => i.install_id)
    const total = ids.length
    if (!total) return
    if (typeof window !== 'undefined') {
      const ok1 = confirm(`Revoke ALL ${total} filtered installations?`)
      if (!ok1) return
      const ok2 = confirm('Are you absolutely sure? This cannot be undone.')
      if (!ok2) return
    }
    busy.value = true
    let okCount = 0
    // Fire requests sequentially to avoid overwhelming the server/audit
    for (const install_id of ids) {
      try {
        const r = await fetch('/api/admin/installations/revoke', {
          method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ install_id })
        })
        if (r.ok) okCount += 1
      } catch (_) { /* ignore individual errors */ }
    }
    await loadInstallations()
    showToast(`Revoked ${okCount}/${total} installations`, okCount === total ? 'success' : (okCount > 0 ? 'info' : 'error'))
  } catch (_) { showToast('Batch revoke failed', 'error') } finally { busy.value = false }
}

// Admin: batch moderation
async function revokeAllInstalls(u) {
  try {
    const user_id = u && u.id
    if (!user_id) return
    const label = u && (u.email || u.id)
    if (typeof window !== 'undefined') {
      const ok = confirm(`Revoke ALL installations for ${label}?`)
      if (!ok) return
    }
    busy.value = true
    const r = await fetch(`/api/admin/users/${encodeURIComponent(user_id)}/revoke-installations`, {
      method: 'POST', credentials: 'include'
    })
    const j = await r.json()
    if (!r.ok || !j.ok) throw new Error('revoke_all_failed')
    await loadInstallations()
    showToast(`Revoked ${j.count || 0} installations`, 'success')
  } catch (_) { showToast('Revoke all failed', 'error') } finally { busy.value = false }
}

async function banAndRevoke(u) {
  try {
    const user_id = u && u.id
    if (!user_id) return
    const label = u && (u.email || u.id)
    if (typeof window !== 'undefined') {
      const ok = confirm(`Ban ${label} and revoke ALL installations?`)
      if (!ok) return
    }
    const reason = (typeof window !== 'undefined') ? (prompt('Ban reason (optional):') || '') : ''
    busy.value = true
    const r = await fetch(`/api/admin/users/${encodeURIComponent(user_id)}/ban-and-revoke`, {
      method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ reason })
    })
    const j = await r.json()
    if (!r.ok || !j.ok) throw new Error('ban_revoke_failed')
    await loadUsers(); await loadBans(); await loadInstallations()
    showToast(`User banned and ${j.count || 0} installs revoked`, 'success')
  } catch (_) { showToast('Ban & Revoke failed', 'error') } finally { busy.value = false }
}

// Persist table prefs
const LS_USERS = 'seedsphere.admin.users.table'
const LS_INSTALLS = 'seedsphere.admin.installs.table'
function saveUsersPrefs() {
  try {
    localStorage.setItem(LS_USERS, JSON.stringify({
      sortKey: userSortKey.value, sortDir: userSortDir.value,
      pageSize: userPageSize.value, query: userQuery.value, onlyBanned: !!userOnlyBanned.value,
      provider: String(userProviderFilter.value || 'all'), hasEmail: !!userHasEmailOnly.value,
    }))
  } catch (_) {}
}
function loadUsersPrefs() {
  try {
    const raw = localStorage.getItem(LS_USERS)
    if (!raw) return
    const v = JSON.parse(raw)
    if (v && typeof v === 'object') {
      if (typeof v.sortKey === 'string') userSortKey.value = v.sortKey
      if (typeof v.sortDir === 'string') userSortDir.value = v.sortDir
      if (Number.isFinite(Number(v.pageSize))) userPageSize.value = Number(v.pageSize)
      if (typeof v.query === 'string') userQuery.value = v.query
      if (typeof v.onlyBanned === 'boolean') userOnlyBanned.value = v.onlyBanned
      if (typeof v.provider === 'string') userProviderFilter.value = v.provider
      if (typeof v.hasEmail === 'boolean') userHasEmailOnly.value = v.hasEmail
    }
  } catch (_) {}
}
function saveInstallsPrefs() {
  try {
    localStorage.setItem(LS_INSTALLS, JSON.stringify({
      sortKey: installSortKey.value, sortDir: installSortDir.value,
      pageSize: installPageSize.value, query: installQuery.value,
    }))
  } catch (_) {}
}
function loadInstallsPrefs() {
  try {
    const raw = localStorage.getItem(LS_INSTALLS)
    if (!raw) return
    const v = JSON.parse(raw)
    if (v && typeof v === 'object') {
      if (typeof v.sortKey === 'string') installSortKey.value = v.sortKey
      if (typeof v.sortDir === 'string') installSortDir.value = v.sortDir
      if (Number.isFinite(Number(v.pageSize))) installPageSize.value = Number(v.pageSize)
      if (typeof v.query === 'string') installQuery.value = v.query
    }
  } catch (_) {}
}
// Bans data
const bans = ref([])
const bansCount = computed(() => Array.isArray(bans.value) ? bans.value.length : 0)
async function loadBans() {
  try {
    const r = await fetch('/api/admin/bans', { credentials: 'include', cache: 'no-store' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('bans_failed')
    bans.value = Array.isArray(j.bans) ? j.bans : []
  } catch (_) { bans.value = [] }
}
const bansDlg = ref(null)
const LS_BANS_OPEN = 'seedsphere.admin.bans.open'
function openBans() {
  try { bansDlg.value?.showModal && bansDlg.value.showModal() } catch (_) {}
  try { localStorage.setItem(LS_BANS_OPEN, '1') } catch (_) {}
}
function closeBans() {
  try { bansDlg.value?.close && bansDlg.value.close() } catch (_) {}
  try { localStorage.setItem(LS_BANS_OPEN, '0') } catch (_) {}
}
function unbanFromBans(b) { if (b && b.user_id) unbanUser({ id: b.user_id, email: '' }) }
async function revokeAllFromBans(b) { if (b && b.user_id) return revokeAllInstalls({ id: b.user_id, email: '' }) }

// Users provider options
const userProviders = computed(() => {
  try {
    const set = new Set()
    for (const u of users.value) { const p = String(u.provider || '').trim(); if (p) set.add(p) }
    return Array.from(set).sort()
  } catch (_) { return [] }
})

// If the persisted provider filter no longer exists in the dataset, reset to 'all'
watch(userProviders, (opts) => {
  try {
    const cur = String(userProviderFilter.value || 'all')
    if (cur !== 'all' && !opts.includes(cur)) userProviderFilter.value = 'all'
  } catch (_) {}
})

const usersFiltered = computed(() => {
  const q = String(userQuery.value || '').toLowerCase()
  let arr = users.value.slice()
  if (q) arr = arr.filter(u => String(u.id).toLowerCase().includes(q) || String(u.email||'').toLowerCase().includes(q))
  const pf = String(userProviderFilter.value || 'all')
  if (pf !== 'all') arr = arr.filter(u => String(u.provider||'') === pf)
  if (userHasEmailOnly.value) arr = arr.filter(u => !!u.email)
  if (userOnlyBanned.value) arr = arr.filter(u => !!u.banned)
  return arr
})
// Users table sorting state and helpers
const userSortKey = ref('created_at') // 'id' | 'provider' | 'email' | 'created_at'
const userSortDir = ref('desc') // 'asc' | 'desc'
function toggleUserSort(key) {
  try {
    if (userSortKey.value === key) {
      userSortDir.value = (userSortDir.value === 'asc') ? 'desc' : 'asc'
    } else {
      userSortKey.value = key
      userSortDir.value = 'asc'
    }
  } catch (_) {}
}
function userField(u, key) {
  try {
    if (key === 'created_at') {
      const t = Date.parse(u?.created_at)
      return Number.isFinite(t) ? t : Number(u?.created_at) || 0
    }
    if (key === 'id') {
      return String(userIdOnly(u)).toLowerCase()
    }
    const v = (key === 'provider') ? u?.provider : (key === 'email') ? u?.email : ''
    return String(v ?? '').toLowerCase()
  } catch (_) { return '' }
}
function userIdOnly(u) {
  try {
    const raw = String(u?.id ?? '')
    const idx = raw.indexOf(':')
    return idx >= 0 ? raw.slice(idx + 1) : raw
  } catch (_) { return String(u?.id ?? '') }
}
function userCompare(a, b) {
  const ka = userField(a, userSortKey.value)
  const kb = userField(b, userSortKey.value)
  const s = ka < kb ? -1 : ka > kb ? 1 : 0
  return (userSortDir.value === 'asc') ? s : -s
}
const usersPaged = computed(() => {
  const start = (userPage.value - 1) * userPageSize.value
  const sorted = usersFiltered.value.slice().sort(userCompare)
  return sorted.slice(start, start + userPageSize.value)
})

const userEmailMap = computed(() => {
  const m = new Map()
  for (const u of users.value) { if (u && u.id) m.set(u.id, u.email || '') }
  return m
})
function userEmail(user_id) { return userEmailMap.value.get(user_id) || '' }

const installationsFiltered = computed(() => {
  const q = String(installQuery.value || '').toLowerCase()
  let arr = installations.value.slice()
  if (q) arr = arr.filter(s => String(s.install_id).toLowerCase().includes(q) || String(userEmail(s.user_id)).toLowerCase().includes(q))
  return arr
})
// Installations table sorting state and helpers
const installSortKey = ref('created_at') // 'install_id' | 'user' | 'status' | 'created_at' | 'last_seen'
const installSortDir = ref('desc')
function toggleInstallSort(key) {
  try {
    if (installSortKey.value === key) {
      installSortDir.value = (installSortDir.value === 'asc') ? 'desc' : 'asc'
    } else {
      installSortKey.value = key
      installSortDir.value = 'asc'
    }
  } catch (_) {}
}

// Persist prefs when controls change
watch([userSortKey, userSortDir, userPageSize, userQuery, userOnlyBanned, userProviderFilter, userHasEmailOnly], saveUsersPrefs)
watch([installSortKey, installSortDir, installPageSize, installQuery], saveInstallsPrefs)

function resetUsersFilters() {
  try {
    userQuery.value = ''
    userProviderFilter.value = 'all'
    userHasEmailOnly.value = false
    userOnlyBanned.value = false
    userPage.value = 1
    saveUsersPrefs()
  } catch (_) {}
}
// Ensure Users page stays in range when filters or page size change
watch([userQuery, userProviderFilter, userHasEmailOnly, userOnlyBanned, userPageSize], () => {
  try { userPage.value = 1 } catch (_) {}
})
watch([usersFiltered, userPageSize], () => {
  try {
    const total = usersFiltered.value.length
    const size = Math.max(1, Number(userPageSize.value) || 1)
    const maxPage = Math.max(1, Math.ceil(total / size))
    if (userPage.value > maxPage) userPage.value = maxPage
  } catch (_) {}
})
function installField(s, key) {
  try {
    if (key === 'created_at' || key === 'last_seen') {
      const raw = (key === 'created_at') ? s?.created_at : s?.last_seen
      const t = Date.parse(raw)
      return Number.isFinite(t) ? t : Number(raw) || 0
    }
    if (key === 'install_id') return String(s?.install_id ?? '').toLowerCase()
    if (key === 'status') return String(s?.status ?? '').toLowerCase()
    if (key === 'user') return String(userEmail(s?.user_id) || s?.user_id || '').toLowerCase()
    return ''
  } catch (_) { return '' }
}
function installCompare(a, b) {
  const ka = installField(a, installSortKey.value)
  const kb = installField(b, installSortKey.value)
  const s = ka < kb ? -1 : ka > kb ? 1 : 0
  return (installSortDir.value === 'asc') ? s : -s
}
const installationsPaged = computed(() => {
  const start = (installPage.value - 1) * installPageSize.value
  const sorted = installationsFiltered.value.slice().sort(installCompare)
  return sorted.slice(start, start + installPageSize.value)
})

// aria-sort helper for accessible headers
function ariaSort(curKey, key, dir) {
  try {
    if (curKey !== key) return 'none'
    return dir === 'asc' ? 'ascending' : 'descending'
  } catch (_) { return 'none' }
}

// Charts: metrics state and helpers
const metrics = ref({ users: [], installs: [] })
const metricsDays = ref(30)
const chartW = 420
const chartH = 80
function sparklinePath(arr) {
  try {
    const pts = (Array.isArray(arr) ? arr : []).map((d, i) => ({ x: i, y: Number((d && (d.c ?? d.count)) || 0) }))
    if (!pts.length) return ''
    const maxX = pts.length - 1
    const maxY = Math.max(1, ...pts.map(p => p.y))
    const sx = chartW / Math.max(1, maxX || 1)
    const sy = (chartH - 4) / Math.max(1, maxY)
    let path = ''
    for (let i = 0; i < pts.length; i++) {
      const x = Math.round(i * sx)
      const y = Math.round(chartH - 2 - pts[i].y * sy)
      path += (i === 0 ? 'M ' : ' L ') + x + ' ' + y
    }
    return path
  } catch (_) { return '' }
}
async function loadMetrics() {
  try {
    const r = await fetch(`/api/admin/metrics/summary?days=${metricsDays.value}`, { credentials: 'include' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('metrics_failed')
    metrics.value = { users: Array.isArray(j.users) ? j.users : [], installs: Array.isArray(j.installs) ? j.installs : [] }
  } catch (_) { /* silent; UI already surfaces generic error */ }
}

// Audit state and helpers
const audit = ref([])
const auditLimit = ref(100)
const auditOffset = ref(0)
const auditPage = computed(() => {
  try {
    const size = Math.max(1, Number(auditLimit.value) || 1)
    const off = Math.max(0, Number(auditOffset.value) || 0)
    return Math.floor(off / size) + 1
  } catch (_) { return 1 }
})
async function loadAudit() {
  try {
    const r = await fetch(`/api/admin/audit?limit=${auditLimit.value}&offset=${auditOffset.value}`, { credentials: 'include' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('audit_failed')
    audit.value = Array.isArray(j.items) ? j.items : []
  } catch (_) { /* silent */ }
}
function prevAudit() { auditOffset.value = Math.max(0, auditOffset.value - auditLimit.value); loadAudit() }
function nextAudit() { auditOffset.value = auditOffset.value + auditLimit.value; loadAudit() }

watch(auditLimit, () => { try { auditOffset.value = 0; loadAudit() } catch (_) {} })
function formatMeta(meta) {
  try {
    if (meta && typeof meta === 'string') {
      try { return JSON.stringify(JSON.parse(meta), null, 2) } catch { return meta }
    }
    // Some drivers return a Uint8Array-like object { data: [...] }
    const bytes = (meta && meta.data && Array.isArray(meta.data)) ? new Uint8Array(meta.data) : null
    if (bytes) { const txt = new TextDecoder().decode(bytes); try { return JSON.stringify(JSON.parse(txt), null, 2) } catch { return txt } }
    return JSON.stringify(meta)
  } catch { return String(meta || '') }
}

// CSV export helpers
function toCsv(arr, headers) {
  const esc = (v) => '"' + String(v ?? '').replace(/"/g, '""') + '"'
  const lines = [headers.join(',')]
  for (const row of arr) lines.push(headers.map(h => esc(row[h])).join(','))
  return lines.join('\n')
}
function downloadText(filename, text) {
  const blob = new Blob([text], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename
  document.body.appendChild(a); a.click(); document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
function exportUsersCsv() {
  const data = usersFiltered.value.map(u => ({ id: u.id, provider: u.provider, email: u.email, created_at: u.created_at }))
  downloadText('users.csv', toCsv(data, ['id','provider','email','created_at']))
}
function exportInstallsCsv() {
  const data = installationsFiltered.value.map(s => ({ install_id: s.install_id, user_id: s.user_id, user_email: userEmail(s.user_id), status: s.status, created_at: s.created_at, last_seen: s.last_seen }))
  downloadText('installations.csv', toCsv(data, ['install_id','user_id','user_email','status','created_at','last_seen']))
}

// User drawer
const userDlg = ref(null)
const activeUser = ref(null)
const userSeedlings = computed(() => {
  const uid = activeUser.value?.id
  if (!uid) return []
  return installations.value.filter(s => s.user_id === uid)
})
function openUser(u) {
  activeUser.value = u
  try { userDlg.value?.showModal && userDlg.value.showModal() } catch (_) {}
}

// Global manifest helpers for actions when per-install secret is not available here
const origin = typeof window !== 'undefined' ? window.location.origin : ''
const globalManifestUrl = computed(() => `${origin}/manifest.json`)
async function copyGlobalManifest() {
  try { await navigator.clipboard.writeText(globalManifestUrl.value) } catch (_) {}
}

async function loadSummary() {
  try {
    const r = await fetch('/api/admin/summary', { credentials: 'include' })
    if (!r.ok) throw new Error('summary_failed')
    const j = await r.json(); if (!j.ok) throw new Error('summary_failed')
    summary.value = j
  } catch (e) { error.value = 'Could not load summary' }
}

async function loadUsers() {
  try {
    const r = await fetch('/api/admin/users', { credentials: 'include' })
    if (!r.ok) throw new Error('users_failed')
    const j = await r.json(); if (!j.ok) throw new Error('users_failed')
    const arr = Array.isArray(j.users) ? j.users : (Array.isArray(j.items) ? j.items : [])
    users.value = arr
    try {
      const total = Number(summary.value?.counts?.users || 0)
      if (total > 0 && users.value.length === 0) {
        showToast('Users list is empty. Try Refresh or re-authenticate.', 'warning', 3500)
      }
    } catch (_) {}
  } catch (e) { error.value = 'Could not load users' }
}

async function loadInstallations() {
  try {
    const r = await fetch('/api/admin/installations', { credentials: 'include' })
    if (!r.ok) throw new Error('installations_failed')
    const j = await r.json(); if (!j.ok) throw new Error('installations_failed')
    installations.value = j.installations || []
  } catch (e) { error.value = 'Could not load installations' }
}

// Settings handlers
async function loadSettings() {
  try {
    const r = await fetch('/api/admin/settings', { credentials: 'include' })
    if (!r.ok) throw new Error('settings_failed')
    const j = await r.json(); if (!j.ok) throw new Error('settings_failed')
    settings.value = Object.assign({}, settings.value, j.settings || {})
  } catch (_) { error.value = 'Could not load settings' }
}
async function saveSettings() {
  busy.value = true
  try {
    const r = await fetch('/api/admin/settings', { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'include', body: JSON.stringify({ settings: settings.value }) })
    if (!r.ok) throw new Error('save_failed')
    showToast('Settings saved', 'success')
  } catch (_) { error.value = 'Could not save settings' } finally { busy.value = false }
}

// Per-install helpers
async function rotateSecret(install_id) {
  if (!install_id) return
  if (!confirm(`Rotate secret for ${install_id}? This will invalidate previous manifest links.`)) return
  busy.value = true
  try {
    const r = await fetch(`/api/admin/installations/${encodeURIComponent(install_id)}/rotate-secret`, { method: 'POST', credentials: 'include' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('rotate_failed')
    try { await navigator.clipboard.writeText(String(j.manifestUrl || '')) } catch (_) {}
    await loadInstallations()
    showToast('Secret rotated. Manifest URL copied', 'success')
  } catch (_) { error.value = 'Rotate secret failed' } finally { busy.value = false }
}
async function generateSignedManifest(install_id) {
  if (!install_id) return
  busy.value = true
  try {
    const r = await fetch(`/api/admin/installations/${encodeURIComponent(install_id)}/signed-manifest`, { method: 'POST', credentials: 'include' })
    const j = await r.json(); if (!r.ok || !j.ok) throw new Error('signed_failed')
    try { await navigator.clipboard.writeText(String(j.url || '')) } catch (_) {}
    showToast('Signed link copied', 'success')
  } catch (_) { error.value = 'Signed link failed' } finally { busy.value = false }
}

async function revoke(install_id) {
  if (!install_id) return
  if (!confirm(`Revoke ${install_id}?`)) return
  busy.value = true
  try {
    const r = await fetch('/api/admin/installations/revoke', { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'include', body: JSON.stringify({ install_id }) })
    if (!r.ok) throw new Error('revoke_failed')
    await loadInstallations()
    showToast('Revoked', 'success')
  } catch (e) { error.value = 'Revoke failed' } finally { busy.value = false }
}

async function remove(install_id) {
  if (!install_id) return
  if (!confirm(`Delete ${install_id}? This cannot be undone.`)) return
  busy.value = true
  try {
    const r = await fetch(`/api/admin/installations/${encodeURIComponent(install_id)}`, { method: 'DELETE', credentials: 'include' })
    if (!r.ok) throw new Error('delete_failed')
    await loadInstallations()
    showToast('Deleted', 'success')
  } catch (e) { error.value = 'Delete failed' } finally { busy.value = false }
}

async function refreshTrackers() {
  busy.value = true
  try {
    const r = await fetch('/api/admin/trackers/refresh', { method: 'POST', credentials: 'include' })
    if (!r.ok) throw new Error('trackers_failed')
    showToast('Trackers refresh requested', 'success')
  } catch (_) { showToast('Trackers refresh failed', 'error') } finally { busy.value = false }
}

async function copyGlobalStremio() {
  try { await navigator.clipboard.writeText(globalManifestUrl.value.replace(/^https?:\/\//, 'stremio://')) ; showToast('Stremio link copied', 'success') } catch (_) { showToast('Copy failed', 'error') }
}

// Filter installations table by selected user and scroll into view
function filterInstallsForUser(u) {
  try {
    const q = (u && (u.email || u.id)) ? (u.email || u.id) : ''
    installQuery.value = q
    installPage.value = 1
    // Scroll to installations table
    try {
      const el = document.getElementById('installations')
      if (el && typeof el.scrollIntoView === 'function') el.scrollIntoView({ behavior: 'smooth', block: 'start' })
    } catch (_) {}
  } catch (_) {}
}

let probeTimer = null
let bpmTimer = null
onMounted(async () => {
  try { await auth.fetchSession() } catch (_) {}
  // Load saved table preferences first so initial loads respect page size and filters
  try { loadUsersPrefs() } catch (_) {}
  try { loadInstallsPrefs() } catch (_) {}
  try { loadGardenersPrefs() } catch (_) {}
  await loadSummary(); await loadUsers(); await loadInstallations(); await loadSettings(); await loadMetrics(); await loadAudit(); await loadBans()
  try { if (localStorage.getItem(LS_BANS_OPEN) === '1') openBans() } catch (_) {}
  await loadErrorsSummary()
  await loadFallbackSummary()
  // Auto provider probe every 5 minutes
  try { probeTimer = setInterval(() => { probeProviders() }, 300_000) } catch (_) {}
  // Start global SSE
  connectBoostsSse('')
  // Boosts/min history ticker every 10s
  try { bpmTimer = setInterval(() => { bpmHistory.value = [...bpmHistory.value, boostsPerMin.value].slice(-60) }, 10_000) } catch (_) {}
})
onBeforeUnmount(() => {
  try { probeTimer && clearInterval(probeTimer) } catch (_) {}
  try { bpmTimer && clearInterval(bpmTimer) } catch (_) {}
  try { esBoosts && esBoosts.close() } catch (_) {}
})
</script>

<style scoped>
</style>
