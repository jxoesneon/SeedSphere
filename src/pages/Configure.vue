<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6 space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 id="install" class="text-2xl font-bold">Configure SeedSphere</h1>
        <div class="flex flex-wrap items-center gap-2">
          <a class="btn btn-primary btn-sm" :href="manifestProtocol">Install / Update</a>
          <RouterLink class="btn btn-ghost btn-sm" to="/">Home</RouterLink>
        </div>
      </div>

      <!-- Toast notifications -->
      <div v-if="toastMsg" class="toast toast-top toast-end z-20">
        <div class="alert" :class="toastType">{{ toastMsg }}</div>
      </div>

      <!-- Update banner -->
      <div v-if="showUpdateBanner" class="alert alert-info">
        <span class="font-semibold">Update available:</span>
        <span class="ml-2">SeedSphere v{{ latestVersion }} is available.</span>
        <div class="ml-auto flex gap-2">
          <a class="btn btn-sm" :href="manifestProtocol">Install</a>
          <button class="btn btn-ghost btn-sm" type="button" @click="dismissUpdate">Dismiss</button>
        </div>
      </div>

      <!-- Quick Navigation -->
      <div class="flex flex-wrap gap-2 sticky top-0 z-10 bg-base-100/80 backdrop-blur supports-[backdrop-filter]:bg-base-100/60 py-2">
        <a class="btn btn-xs" href="#install">Install</a>
        <a class="btn btn-xs" href="#upstream">Upstream</a>
        <a class="btn btn-xs" href="#prefs">Prefs</a>
        <a class="btn btn-xs" href="#sources">Sources</a>
        <a class="btn btn-xs" href="#opt">Optimization</a>
        <a class="btn btn-xs" href="#sweep">Sweep</a>
        <a class="btn btn-xs" href="#lists">Allow/Block</a>
        <a class="btn btn-xs" href="#telemetry">Telemetry</a>
      </div>

      <div class="columns-1 md:columns-2 gap-x-4">
        <!-- Recent Boosts -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <div class="flex items-center gap-2">
              <h2 id="telemetry" class="card-title">Recent Boosts</h2>
              <span class="inline-block w-2.5 h-2.5 rounded-full"
                :class="{
                  'bg-blue-500': sseStatus === 'waiting',
                  'bg-green-500': sseStatus === 'ok',
                  'bg-yellow-500': sseStatus === 'warn',
                  'bg-red-500': sseStatus === 'error',
                }"
                :title="`Status: ${sseStatus}`"
              ></span>
            </div>
            <p class="text-xs opacity-70">Listening to <code>/api/boosts/events</code></p>
            <div class="overflow-x-auto rounded-box bg-base-300/50 p-2">
              <table class="table table-zebra table-sm">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Type</th>
                    <th>ID</th>
                    <th>Title</th>
                    <th>Healthy</th>
                    <th>Total</th>
                    <th>Mode</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(it, idx) in boosts" :key="idx">
                    <td>{{ fmtTime(it.ts || Date.now()) }}</td>
                    <td>{{ it.type }}</td>
                    <td class="truncate max-w-[12rem]" :title="it.id">{{ it.id }}</td>
                    <td class="truncate max-w-[16rem]" :title="it.title">{{ it.title }}</td>
                    <td>{{ it.healthy }}</td>
                    <td>{{ it.total }}</td>
                    <td>{{ it.mode }}</td>
                  </tr>
                  <tr v-if="boosts.length === 0">
                    <td colspan="7" class="text-center opacity-60">No events yet</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Upstream Proxy (own card, collapsible) -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary id="upstream" class="collapse-title text-base font-semibold">Upstream Proxy</summary>
              <div class="collapse-content p-0">
                <div class="p-3 rounded-box bg-base-300/50 space-y-2">
                  <div class="flex items-center gap-2">
                    <div class="badge badge-info">Proxy</div>
                    <span class="text-sm opacity-80">Upstream auto‑proxy</span>
                  </div>
                  <p class="text-sm">Status: <b :class="autoProxy ? 'text-success' : 'text-error'">{{ autoProxy ? 'Enabled' : 'Disabled' }}</b>. Configure in <a href="#prefs" class="link">Preferences</a>.</p>
                  <p class="text-xs opacity-70">When enabled, SeedSphere queries available upstream providers server‑side, augments their magnets with an optimized trackers list, and returns the result as its own streams in Stremio.</p>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Preferences Card (no stream label) -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary id="prefs" class="collapse-title text-base font-semibold">Preferences</summary>
              <div class="collapse-content p-0">
                <div class="grid md:grid-cols-2 gap-4 p-3 rounded-box bg-base-300/50">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                      <div class="badge badge-info">Proxy</div>
                      <span class="text-sm opacity-80">Upstream auto‑proxy</span>
                    </div>
                    <label class="label cursor-pointer gap-2">
                      <span class="label-text text-sm">Enable</span>
                      <input type="checkbox" class="toggle" v-model="autoProxy" />
                    </label>
                  </div>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Description Settings Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary class="collapse-title text-base font-semibold">Descriptions</summary>
              <div class="collapse-content p-0">
                <div class="grid md:grid-cols-2 gap-4 p-3 rounded-box bg-base-300/50">
                  <label class="label cursor-pointer gap-2">
                    <span class="label-text">Append original provider description</span>
                    <input type="checkbox" class="toggle" v-model="descAppendOriginal" />
                  </label>
                  <label class="label cursor-pointer gap-2">
                    <span class="label-text">Use original description when no details parsed</span>
                    <input type="checkbox" class="toggle" v-model="descRequireDetails" />
                  </label>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- AI Descriptions Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full" ref="aiCard">
          <div class="card-body p-3 md:p-4 relative">
            <details open class="collapse">
              <summary class="collapse-title text-base font-semibold">AI Descriptions</summary>
              <div class="collapse-content p-0">
                <div class="grid gap-4 p-3 rounded-box bg-base-300/50">
                  <label class="label cursor-pointer gap-2">
                    <span class="label-text">Enable AI enhanced descriptions</span>
                    <input type="checkbox" class="toggle" :checked="aiEnabled" @change="onToggleAi($event)" />
                  </label>

                  <div class="text-xs opacity-70 -mt-2">Requires a saved server key for the selected provider. You can override defaults below.</div>

                  <div v-if="aiEnabled" class="grid gap-4">
                    <!-- Mode presets -->
                    <div class="grid gap-2">
                      <div class="label"><span class="label-text">Mode presets</span></div>
                      <div class="flex flex-wrap gap-3">
                        <label class="inline-flex items-center gap-2">
                          <input type="radio" class="radio" value="fast" v-model="presetMode" @change="applyAiPreset" />
                          <span>Fast</span>
                        </label>
                        <label class="inline-flex items-center gap-2">
                          <input type="radio" class="radio" value="balanced" v-model="presetMode" @change="applyAiPreset" />
                          <span>Balanced</span>
                        </label>
                        <label class="inline-flex items-center gap-2">
                          <input type="radio" class="radio" value="rich" v-model="presetMode" @change="applyAiPreset" />
                          <span>Rich</span>
                        </label>
                      </div>
                      <div class="text-xs opacity-70">Presets map to model/timeout/cache defaults. You can override below.</div>
                    </div>

                    <div class="grid md:grid-cols-2 gap-4">
                      <!-- Provider -->
                      <label class="form-control">
                        <div class="label"><span class="label-text">Provider</span></div>
                        <select v-model="aiProvider" class="select select-bordered" @change="onProviderChange">
                          <option v-for="opt in AI_PROVIDER_OPTIONS" :key="opt" :value="opt">{{ opt }}</option>
                        </select>
                      </label>

                      <!-- Model / Deployment -->
                      <label class="form-control" v-if="aiProvider !== 'azure'">
                        <div class="label"><span class="label-text">Model</span></div>
                        <select v-model="aiModel" class="select select-bordered">
                          <option v-for="m in availableAiModels" :key="m" :value="m">{{ m }}</option>
                        </select>
                        <p v-if="aiProvider === 'openai'" class="text-xs opacity-70 mt-1">Examples: gpt-5, gpt-5-mini, gpt-4.1, gpt-4o, o3-mini.</p>
                        <p v-else-if="aiProvider === 'anthropic'" class="text-xs opacity-70 mt-1">Examples: claude-4-opus, claude-4-sonnet, claude-4-haiku.</p>
                        <p v-else-if="aiProvider === 'google'" class="text-xs opacity-70 mt-1">Examples: gemini-2.5-pro, gemini-2.5-flash.</p>
                      </label>
                      <label class="form-control" v-else>
                        <div class="label"><span class="label-text">Deployment name (Azure)</span></div>
                        <input v-model="aiModel" class="input input-bordered" placeholder="e.g. gpt-4o-prod" />
                        <p class="text-xs opacity-70 mt-1">Azure uses deployment names instead of model ids.</p>
                      </label>
                    </div>

                    <!-- Provider key check warning -->
                    <div v-if="!hasServerKey(aiProvider)" class="alert alert-warning">
                      <span>No server key is saved for <b class="uppercase">{{ aiProvider }}</b>. Manage it below.</span>
                      <div class="ml-auto">
                        <button class="btn btn-sm" type="button" @click="goManageKeysFor(aiProvider)">Manage keys</button>
                      </div>
                    </div>

                    <!-- Advanced performance -->
                    <details class="collapse">
                      <summary class="collapse-title p-0 text-sm font-semibold">Advanced</summary>
                      <div class="collapse-content p-0 mt-2 grid md:grid-cols-2 gap-4">
                        <label class="form-control">
                          <div class="label"><span class="label-text">Timeout (ms)</span></div>
                          <input v-model.number="aiTimeoutMs" type="number" min="0" class="input input-bordered" />
                        </label>
                        <label class="form-control">
                          <div class="label"><span class="label-text">Cache TTL (ms)</span></div>
                          <input v-model.number="aiCacheTtlMs" type="number" min="0" class="input input-bordered" />
                        </label>
                      </div>
                    </details>
                  </div>
                </div>
                <p class="text-xs opacity-70 px-3 pb-3">AI requires sign‑in and a provider key saved on the server.</p>

                <!-- Login blur overlay -->
                <div v-if="showLoginOverlay" class="absolute inset-0 bg-base-100/70 backdrop-blur-sm flex items-center justify-center rounded-box">
                  <div class="card bg-base-200 shadow w-full max-w-md">
                    <div class="card-body gap-3">
                      <h3 class="font-semibold text-lg">Sign in to use AI descriptions</h3>
                      <p class="text-sm opacity-80">We store provider keys securely on your account. Please sign in to continue.</p>
                      <div class="flex flex-col gap-2">
                        <div class="join">
                          <input v-model="magicEmail" type="email" placeholder="you@example.com" class="input input-bordered join-item" />
                          <button class="btn btn-primary join-item" type="button" @click="startMagicLink">Email me a sign-in link</button>
                        </div>
                        <a class="btn" href="/api/auth/google/start">Sign in with Google</a>
                        <button class="btn btn-ghost" type="button" @click="showLoginOverlay = false">Dismiss</button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Account & AI Keys (server-side) -->
                <div class="px-3 pb-4 space-y-3" ref="keysSection">
                  <div class="flex items-center justify-between">
                    <div class="text-sm">Status: <b>{{ sessionUserId ? 'Signed in' : 'Signed out' }}</b></div>
                    <div class="flex flex-wrap gap-2 items-center">
                      <template v-if="!sessionUserId">
                        <div class="join">
                          <input v-model="magicEmail" type="email" placeholder="you@example.com" class="input input-bordered input-sm join-item" />
                          <button class="btn btn-sm join-item" type="button" @click="startMagicLink">Magic link</button>
                        </div>
                        <a class="btn btn-sm" href="/api/auth/google/start">Google</a>
                      </template>
                      <button v-else class="btn btn-ghost btn-sm" @click="logout">Logout</button>
                    </div>
                  </div>

                  <div class="divider">AI Keys (server)</div>
                  <div class="grid md:grid-cols-4 gap-2 items-end">
                    <label class="form-control">
                      <div class="label"><span class="label-text">Provider</span></div>
                      <select v-model="srvProvider" class="select select-bordered select-sm">
                        <option v-for="opt in AI_PROVIDER_OPTIONS" :key="`srv-${opt}`" :value="opt">{{ opt }}</option>
                      </select>
                    </label>
                    <label class="form-control md:col-span-2">
                      <div class="label"><span class="label-text">API key (server)</span></div>
                      <input ref="srvApiKeyInput" v-model="srvApiKey" type="password" class="input input-bordered input-sm" placeholder="Stored encrypted on server" />
                    </label>
                    <button class="btn btn-sm" type="button" :disabled="!sessionUserId" @click="saveKeyServer">Save</button>
                  </div>

                  <div>
                    <div class="text-sm opacity-70 mb-1">Saved providers</div>
                    <div class="overflow-x-auto rounded-box bg-base-300/40">
                      <table class="table table-sm">
                        <thead><tr><th>Provider</th><th></th></tr></thead>
                        <tbody>
                          <tr v-for="it in srvKeys" :key="it.provider">
                            <td class="uppercase">{{ it.provider }}</td>
                            <td class="text-right"><button class="btn btn-ghost btn-xs" @click="deleteKeyServer(it.provider)">Delete</button></td>
                          </tr>
                          <tr v-if="srvKeys.length === 0">
                            <td colspan="2" class="opacity-60">None</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Credentialed Providers (Local Only) -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary class="collapse-title text-base font-semibold">Credentialed Providers (Local)</summary>
              <div class="collapse-content p-0">
                <div class="p-3 rounded-box bg-base-300/50 space-y-3">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                      <div class="badge badge-warning">Local</div>
                      <span class="text-sm opacity-80">Torznab (Jackett / Prowlarr)</span>
                    </div>
                    <label class="label cursor-pointer gap-2">
                      <span class="label-text text-sm">Enable</span>
                      <input type="checkbox" class="toggle" :checked="credentialedEnabled.Torznab" @change="setCredentialedEnabled('Torznab', $event.target.checked)" />
                    </label>
                  </div>
                  <p class="text-xs opacity-70">Credentials are stored only in your browser (localStorage). They are not sent to the server and are excluded from share links.</p>
                  <div v-if="credentialedEnabled.Torznab" class="space-y-2">
                    <div class="flex justify-between items-center">
                      <div class="badge badge-info">Endpoints</div>
                      <button class="btn btn-xs" type="button" @click="addTorznabEndpoint">Add endpoint</button>
                    </div>
                    <div v-if="!credentialedData.Torznab || credentialedData.Torznab.length === 0" class="text-sm opacity-60">No endpoints configured.</div>
                    <div v-for="(ep, i) in credentialedData.Torznab" :key="'torznab-'+i" class="p-2 rounded-box bg-base-200/60 space-y-2">
                      <div class="grid md:grid-cols-2 gap-2">
                        <label class="form-control">
                          <div class="label"><span class="label-text">URL</span></div>
                          <input :value="ep.url" @input="updateTorznabEndpoint(i, 'url', $event.target.value)" type="url" placeholder="http://localhost:9117/api/v2.0/indexers/all/results/torznab/" class="input input-bordered" />
                        </label>
                        <label class="form-control">
                          <div class="label"><span class="label-text">API Key</span></div>
                          <input :value="ep.apiKey" @input="updateTorznabEndpoint(i, 'apiKey', $event.target.value)" type="password" placeholder="••••••" class="input input-bordered" />
                        </label>
                      </div>
                      <div class="flex items-center justify-between gap-2">
                        <div class="text-xs opacity-70">
                          <span v-if="torznabTests[i]?.status === 'ok'" class="text-success">OK ({{ torznabTests[i]?.ms }} ms)</span>
                          <span v-else-if="torznabTests[i]?.status === 'error'" class="text-error">{{ torznabTests[i]?.message || 'Failed' }}</span>
                          <span v-else-if="torznabTests[i]?.status === 'testing'">Testing…</span>
                          <span v-else>Not tested</span>
                        </div>
                        <div class="flex items-center gap-2">
                          <button class="btn btn-xs" type="button" @click="testTorznabEndpoint(i)" :disabled="torznabTests[i]?.status === 'testing'">Test</button>
                          <button class="btn btn-ghost btn-xs" type="button" @click="removeTorznabEndpoint(i)">Remove</button>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="divider my-1"></div>

                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                      <div class="badge badge-warning">Local</div>
                      <span class="text-sm opacity-80">Real-Debrid</span>
                    </div>
                    <label class="label cursor-pointer gap-2">
                      <span class="label-text text-sm">Enable</span>
                      <input type="checkbox" class="toggle" :checked="credentialedEnabled.RealDebrid" @change="setCredentialedEnabled('RealDebrid', $event.target.checked)" />
                    </label>
                  </div>
                  <div v-if="credentialedEnabled.RealDebrid" class="space-y-2">
                    <label class="form-control">
                      <div class="label"><span class="label-text">API Token</span></div>
                      <input :value="credentialedData.RealDebrid.token" @input="updateRealDebridField('token', $event.target.value)" type="password" placeholder="••••••" class="input input-bordered" />
                    </label>
                  </div>

                  <div class="divider my-1"></div>

                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                      <div class="badge badge-warning">Local</div>
                      <span class="text-sm opacity-80">AllDebrid</span>
                    </div>
                    <label class="label cursor-pointer gap-2">
                      <span class="label-text text-sm">Enable</span>
                      <input type="checkbox" class="toggle" :checked="credentialedEnabled.AllDebrid" @change="setCredentialedEnabled('AllDebrid', $event.target.checked)" />
                    </label>
                  </div>
                  <div v-if="credentialedEnabled.AllDebrid" class="space-y-2">
                    <label class="form-control">
                      <div class="label"><span class="label-text">API Key</span></div>
                      <input :value="credentialedData.AllDebrid.apiKey" @input="updateAllDebridField('apiKey', $event.target.value)" type="password" placeholder="••••••" class="input input-bordered" />
                    </label>
                  </div>

                  <div class="divider my-1"></div>

                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                      <div class="badge badge-warning">Local</div>
                      <span class="text-sm opacity-80">Orion</span>
                    </div>
                    <label class="label cursor-pointer gap-2">
                      <span class="label-text text-sm">Enable</span>
                      <input type="checkbox" class="toggle" :checked="credentialedEnabled.Orion" @change="setCredentialedEnabled('Orion', $event.target.checked)" />
                    </label>
                  </div>
                  <div v-if="credentialedEnabled.Orion" class="space-y-2">
                    <div class="grid md:grid-cols-2 gap-2">
                      <label class="form-control">
                        <div class="label"><span class="label-text">API Key</span></div>
                        <input :value="credentialedData.Orion.apiKey" @input="updateOrionField('apiKey', $event.target.value)" type="password" placeholder="••••••" class="input input-bordered" />
                      </label>
                      <label class="form-control">
                        <div class="label"><span class="label-text">User ID</span></div>
                        <input :value="credentialedData.Orion.userId" @input="updateOrionField('userId', $event.target.value)" type="text" placeholder="username or id" class="input input-bordered" />
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            </details>
          </div>
        </div>

        

        <!-- Tracker Sources Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary id="sources" class="collapse-title text-base font-semibold">Tracker Sources</summary>
              <div class="collapse-content p-0">
                <div class="grid md:grid-cols-2 gap-4">
                  <label class="form-control">
                    <div class="label"><span class="label-text">Variant</span></div>
                    <select v-model="variant" class="select select-bordered">
                      <option value="all">All trackers (default)</option>
                      <option value="best">Best curated trackers</option>
                      <option value="all_udp">All UDP trackers</option>
                      <option value="all_http">All HTTP trackers</option>
                      <option value="all_https">All HTTPS trackers</option>
                      <option value="all_ws">All WebSocket trackers</option>
                      <option value="all_i2p">All I2P trackers</option>
                      <option value="all_ip">All trackers (IP only)</option>
                      <option value="best_ip">Best trackers (IP only)</option>
                    </select>
                  </label>

                  <label class="form-control">
                    <div class="label"><span class="label-text">Custom trackers URL (overrides variant)</span></div>
                    <div class="flex gap-2">
                      <input v-model="url" class="input input-bordered flex-1" type="url" placeholder="https://.../trackers.txt" />
                      <button class="btn" type="button" @click="runValidate" :disabled="busy">Validate</button>
                    </div>
                    <div v-if="validateMsg" class="alert mt-2" :class="validateOk ? 'alert-success' : 'alert-error'">{{ validateMsg }}</div>
                  </label>
                </div>
                <div class="flex flex-wrap gap-2 mt-3">
                  <button class="btn" type="button" @click="applyPreset('default')">Preset: Default</button>
                  <button class="btn" type="button" @click="applyPreset('minimal')">Preset: Minimal</button>
                  <button class="btn" type="button" @click="applyPreset('aggressive')">Preset: Aggressive</button>
                  <button class="btn" type="button" @click="copyShareLink">Copy share link</button>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Detected Providers Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary class="collapse-title text-base font-semibold">Detected Providers</summary>
              <div class="collapse-content p-0">
                <div class="p-3 rounded-box bg-base-300/50 space-y-2">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                      <div class="badge badge-info">Providers</div>
                      <span class="text-sm opacity-80">Detected upstreams</span>
                    </div>
                    <button class="btn btn-xs" type="button" @click="detectProviders" :disabled="busyProviders">Refresh</button>
                  </div>
                  <div v-if="providers.length === 0" class="text-sm opacity-60">No providers detected yet.</div>
                  <div v-else class="text-sm">
                    <template v-for="(grp, gi) in groupedProviders" :key="gi">
                      <div class="divider" v-if="grp.items.length">{{ grp.title }}</div>
                      <ul v-if="grp.items.length">
                        <li v-for="p in grp.items" :key="p.name" class="flex items-center justify-between gap-3">
                          <label class="label cursor-pointer gap-2 m-0 p-0">
                            <input type="checkbox" class="toggle toggle-xs" :checked="isProviderEnabled(p.name)" @change="toggleProvider(p.name, $event.target.checked)"/>
                            <span>{{ p.name }}</span>
                          </label>
                          <span :title="providerTooltip(p)" :class="p.ok ? 'text-success' : 'text-error'">{{ p.ok ? `OK (${p.ms} ms)` : 'Unavailable' }}</span>
                        </li>
                      </ul>
                    </template>
                  </div>
                  <p class="text-xs opacity-60">Server endpoint: <code>/api/providers/detect</code></p>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Optimization Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary id="opt" class="collapse-title text-base font-semibold">Optimization</summary>
              <div class="collapse-content p-0">
                <div class="grid grid-cols-1 gap-2">
                  <label class="form-control">
                    <div class="label"><span class="label-text">Validation mode</span></div>
                    <select v-model="mode" class="select select-bordered">
                      <option value="off">Off (fastest)</option>
                      <option value="basic">Basic (DNS + HTTP HEAD)</option>
                      <option value="aggressive">Aggressive (more probes)</option>
                    </select>
                    <p class="text-xs opacity-70 mt-1">Basic removes clearly dead trackers using light checks and a cache. Aggressive may be slower and noisier.</p>
                  </label>
                  <label class="form-control">
                    <div class="label"><span class="label-text">Tracker health cache</span></div>
                    <div class="flex gap-2">
                      <button class="btn" type="button" @click="checkHealth" :disabled="busyHealth">Check health</button>
                    </div>
                    <div v-if="healthData" class="mt-2 p-3 rounded-box bg-base-300/50 text-sm">
                      <div class="flex flex-wrap gap-2 items-center">
                        <div class="badge badge-info">Health</div>
                        <div>Cache size: <b>{{ (healthData.size || 0) }}</b></div>
                        <div>Healthy: <b>{{ (healthData.healthy || 0) }}</b></div>
                        <div>Unhealthy: <b>{{ (healthData.unhealthy || 0) }}</b></div>
                        <div>Updated: <b>{{ fmtTime(healthData.updated_ts || Date.now()) }}</b></div>
                      </div>
                      <div class="mt-2">
                        <button class="btn btn-xs btn-ghost" type="button" @click="showAdvancedHealth = !showAdvancedHealth">Advanced</button>
                        <div v-if="showAdvancedHealth" class="mt-2 flex gap-2">
                          <button class="btn btn-xs btn-outline" type="button" @click="copyHealthDiagnostics">Copy diagnostics</button>
                        </div>
                      </div>
                    </div>
                  </label>
                </div>

                <div>
                  <div class="label"><span class="label-text">Quick sweep (current list)</span></div>
                  <div class="flex gap-2 items-center">
                    <button class="btn" type="button" @click="quickSweep" :disabled="busy">Run quick sweep</button>
                    <div v-if="quickRunning" class="flex-1">
                      <div class="w-full h-2 rounded bg-base-300 overflow-hidden">
                        <div class="h-2 bg-primary animate-pulse w-1/3"></div>
                      </div>
                    </div>
                  </div>
                  <div v-if="quickData" class="mt-2 p-3 rounded-box bg-base-300/50 text-sm">
                    <div class="flex flex-wrap items-center gap-2">
                      <div class="badge badge-success">Result</div>
                      <div>Total: <b>{{ quickData.total || 0 }}</b></div>
                      <div>Healthy: <b>{{ quickData.healthy || 0 }}</b></div>
                      <div>Mode: <code>{{ quickData.mode || 'n/a' }}</code></div>
                      <div>Limit: <code>{{ (quickData.limit || 0) > 0 ? quickData.limit : 'Unlimited' }}</code></div>
                    </div>
                    <div class="mt-2">
                      <button class="btn btn-xs btn-ghost" type="button" @click="showAdvancedQuick = !showAdvancedQuick">Advanced</button>
                      <div v-if="showAdvancedQuick" class="mt-2 flex gap-2">
                        <button class="btn btn-xs btn-outline" type="button" @click="copyQuickDiagnostics">Copy diagnostics</button>
                      </div>
                    </div>
                  </div>
                  <p class="text-xs opacity-70 mt-1">Uses the Custom URL if provided; otherwise uses the selected Variant. Defaults to unlimited; enable limit to cap results.</p>
                </div>

                <div class="divider"></div>

                <div class="grid md:grid-cols-2 gap-4">
                  <div>
                    <div class="label"><span class="label-text">Boosts metrics</span></div>
                    <div class="p-3 rounded-box bg-base-300/50 text-sm whitespace-pre-wrap">{{ boostsMetrics }}</div>
                  </div>
                  <div>
                    <div class="flex items-center justify-between">
                      <div class="label"><span class="label-text">Recent boosts</span></div>
                      <button class="btn btn-sm" type="button" @click="loadRecentBoosts" aria-label="Refresh recent boosts">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4">
                          <path fill-rule="evenodd" d="M12 4a8 8 0 106.32 12.906.75.75 0 011.06 1.06A9.5 9.5 0 1112 2.5v1.75a.75.75 0 001.5 0V2.5A9.5 9.5 0 1121.38 7.47a.75.75 0 01-1.26.82A8 8 0 0012 4z" clip-rule="evenodd" />
                        </svg>
                      </button>
                    </div>
                    <ul class="menu bg-base-300/50 rounded-box">
                      <li v-for="(b, i) in recentBoosts" :key="i"><span>{{ fmtTime(b.ts || Date.now()) }} — {{ b.type }} — {{ b.title }} ({{ b.healthy }}/{{ b.total }})</span></li>
                      <li v-if="recentBoosts.length === 0" class="opacity-60"><span>No recent items</span></li>
                    </ul>
                  </div>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Sweep Tools Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary id="sweep" class="collapse-title text-base font-semibold">Sweep Tools</summary>
              <div class="collapse-content space-y-3">
                <div class="flex flex-wrap gap-2">
                  <button class="btn btn-primary" @click="runSweep" :disabled="busy">Sweep</button>
                  <button class="btn" @click="runValidate" :disabled="busy">Validate</button>
                  <button class="btn" @click="quickSweep" :disabled="busy">Quick sweep</button>
                  <button v-if="quickList.length" class="btn btn-outline" type="button" @click="downloadMerged">Download merged (.txt)</button>
                </div>
                <div v-if="validateMsg" class="alert mt-2" :class="validateOk ? 'alert-success' : 'alert-error'">{{ validateMsg }}</div>
                <div v-if="error" class="alert alert-error">{{ error }}</div>
                <div v-if="sweepStreaming || sweepStats" class="p-3 rounded-box bg-base-300/50 space-y-2">
                  <div v-if="sweepStreaming" class="space-y-2">
                    <div class="flex flex-wrap items-center gap-2">
                      <div class="badge badge-info">Sweep</div>
                      <div class="text-sm">
                        Progress: <strong>{{ sweepProgress.processed }}</strong> / {{ sweepProgress.total }}

async function fetchPairStatus() {
  if (!installId.value) return
  try {
    const u = new URL('/api/pair/status', window.location.origin)
    u.searchParams.set('install_id', installId.value)
    const r = await fetch(u.toString(), { cache: 'no-store' })
    if (!r.ok) return
    const j = await r.json()
    if (j && j.ok) {
      if (j.paired && j.device_id) {
        deviceId.value = j.device_id
        pairingMsg.value = 'Paired successfully.'
      }
    }
  } catch (_) { /* ignore */ }
}

async function regeneratePairCode() {
  if (!installId.value) return
  try {
    const res = await fetch('/api/pair/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ install_id: installId.value }),
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const j = await res.json()
    if (j && j.pair_code) {
      pairCode.value = j.pair_code
      try { localStorage.setItem('seedsphere.pair_code', j.pair_code) } catch (_) {}
      pairingMsg.value = 'New pair code generated.'
      showToast('Pair code regenerated', 'success')
    }
  } catch (e) {
    showToast(e?.message || 'Failed to regenerate', 'error')
  }
}
                        — Healthy so far: <strong>{{ sweepProgress.healthy }}</strong>
                        — Mode: <code>{{ mode }}</code>
                      </div>
                    </div>
                    <div class="w-full h-3 rounded bg-base-300 overflow-hidden">
                      <div class="h-3 bg-primary" :style="{ width: (sweepProgress.total ? Math.round((sweepProgress.processed / sweepProgress.total) * 100) : 0) + '%' }"></div>
                    </div>
                  </div>
                  <div v-if="!sweepStreaming && sweepStats" class="flex flex-wrap items-center gap-2">
                    <div class="badge badge-info">Sweep</div>
                    <div class="text-sm">
                      Healthy: <strong>{{ sweepStats.healthy }}</strong> / {{ sweepStats.total }}
                      ({{ sweepStats.pct }}%).
                      Mode: <code>{{ sweepStats.mode }}</code>.
                      Limit: <code>{{ sweepStats.limit > 0 ? sweepStats.limit : 'Unlimited' }}</code>.
                    </div>
                  </div>
                  <div v-if="!sweepStreaming && sweepStats" class="w-full h-3 rounded bg-base-300 overflow-hidden">
                    <div class="h-3 bg-primary" :style="{ width: (sweepStats.pct || 0) + '%' }"></div>
                  </div>
                  <div v-if="!sweepStreaming && sweepStats" class="flex flex-wrap items-center gap-2">
                    <div class="text-sm">Merged ({{ manualMergeMode }}): <strong>{{ sweepStats.merged }}</strong> trackers</div>
                    <button class="btn btn-xs btn-outline" type="button" @click="downloadSweepMerged">Download merged (.txt)</button>
                    <button class="btn btn-xs btn-outline" type="button" @click="downloadFiltered" v-if="filteredSweepList.length">Download filtered (.txt)</button>
                  </div>
                </div>
                <!-- Filtered preview from last sweep -->
                <div v-if="filteredSweepList.length" class="p-3 rounded-box bg-base-300/50">
                  <div class="flex flex-wrap items-center gap-2">
                    <div class="badge badge-info">Filtered preview</div>
                    <div class="text-sm">{{ filteredSweepList.length }} / {{ lastSweepList.length }} trackers after allow/block</div>
                    <button class="btn btn-xs btn-outline" type="button" @click="copyFiltered">Copy filtered</button>
                    <button class="btn btn-xs btn-outline" type="button" @click="downloadFiltered">Download filtered (.txt)</button>
                  </div>
                  <pre class="mt-2 text-xs whitespace-pre-wrap">{{ filteredSweepList.slice(0, 200).join('\n') }}<span v-if="filteredSweepList.length > 200">\n... (truncated)</span></pre>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Allow / Block Lists Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary id="lists" class="collapse-title text-base font-semibold">Allow / Block Lists</summary>
              <div class="collapse-content">
                <div class="grid md:grid-cols-2 gap-4">
                  <label class="form-control">
                    <div class="label"><span class="label-text">Allowlist (prioritize)</span></div>
                    <textarea v-model="allowlist" class="textarea textarea-bordered h-auto min-h-28 resize-y" placeholder="one.domain.com\nhttps://tracker.example:443/announce"></textarea>
                  </label>
                  <label class="form-control">
                    <div class="label"><span class="label-text">Blocklist (exclude)</span></div>
                    <textarea v-model="blocklist" class="textarea textarea-bordered h-auto min-h-28 resize-y" placeholder="bad.tracker.tld\nudp://1.2.3.4:6969"></textarea>
                  </label>
                </div>
                <div class="mt-2">
                  <button class="btn btn-sm" type="button" @click="applyAllowBlockNow">Apply</button>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Manual Trackers Card -->
        <div class="card bg-base-200 shadow-sm break-inside-avoid mb-4 w-full">
          <div class="card-body p-3 md:p-4">
            <details open class="collapse">
              <summary class="collapse-title text-base font-semibold">Manual Trackers</summary>
              <div class="collapse-content space-y-3">
                <div class="flex items-end gap-2">
                  <label class="form-control flex-1">
                    <div class="label"><span class="label-text">Add a tracker</span></div>
                    <input v-model="manualNew" class="input input-bordered" placeholder="udp://host:port or https://.../announce" />
                  </label>
                  <button class="btn" type="button" @click="addManualRow" aria-label="Add">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5"><path d="M12 4.5a1 1 0 011 1V11h5.5a1 1 0 010 2H13v5.5a1 1 0 01-2 0V13H5.5a1 1 0 010-2H11V5.5a1 1 0 011-1z"/></svg>
                  </button>
                </div>
                <div class="overflow-x-auto">
                  <table class="table table-zebra table-sm">
                    <thead>
                      <tr><th class="w-10">#</th><th>Tracker URL</th><th class="w-28">Actions</th></tr>
                    </thead>
                    <tbody>
                      <tr v-for="(row, i) in manualStaged" :key="i">
                        <td class="text-xs opacity-70">{{ i + 1 }}</td>
                        <td>
                          <input v-model="manualStaged[i]" class="input input-bordered input-sm w-full" :class="{ 'input-error': row && !isValidTracker(row) && manualStrict }" />
                        </td>
                        <td>
                          <button class="btn btn-ghost btn-xs" type="button" @click="removeManualRow(i)" aria-label="Remove">
                            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4"><path d="M9 3.75A1.75 1.75 0 0110.75 2h2.5A1.75 1.75 0 0115 3.75V5h4.25a.75.75 0 010 1.5H4.75a.75.75 0 010-1.5H9V3.75zM6.75 7.5h10.5l-.69 11.042a2.25 2.25 0 01-2.245 2.083H9.685a2.25 2.25 0 01-2.245-2.082L6.75 7.5z"/></svg>
                          </button>
                        </td>
                      </tr>
                      <tr v-if="manualStaged.length === 0"><td colspan="3" class="opacity-60">No manual trackers</td></tr>
                    </tbody>
                  </table>
                </div>
                <div class="grid items-end gap-3 md:grid-cols-3">
                  <label class="label cursor-pointer gap-2">
                    <span class="label-text">Strict validation</span>
                    <input type="checkbox" class="toggle" v-model="manualStrict" />
                  </label>
                  <label class="form-control max-w-56">
                    <div class="label"><span class="label-text">Sweep merge</span></div>
                    <select v-model="manualMergeMode" class="select select-bordered select-sm">
                      <option value="append">Append</option>
                      <option value="replace">Replace</option>
                    </select>
                  </label>
                  <label class="label cursor-pointer gap-2">
                    <span class="label-text">Auto-save after sweep</span>
                    <input type="checkbox" class="toggle" v-model="manualAutoSave" />
                  </label>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button class="btn btn-outline" type="button" @click="importManual" aria-label="Import">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4"><path d="M12 3a1 1 0 011 1v8l3.293-3.293a1 1 0 111.414 1.414l-5 5a1 1 0 01-1.414 0l-5-5A1 1 0 116.707 8.707L10 12V4a1 1 0 011-1z"/></svg>
                    <span class="ml-1">Import</span>
                  </button>
                  <button class="btn btn-outline" type="button" @click="exportManual" aria-label="Export">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4"><path d="M12 21a1 1 0 01-1-1v-8L7.707 15.293a1 1 0 01-1.414-1.414l5-5a1 1 0 011.414 0l5 5a1 1 0 11-1.414 1.414L13 12v8a1 1 0 01-1 1z"/></svg>
                    <span class="ml-1">Export</span>
                  </button>
                </div>
                <div class="mt-2 flex flex-wrap gap-2">
                  <button class="btn btn-primary" type="button" @click="saveManual">Save</button>
                  <button class="btn" type="button" @click="revertManual">Revert</button>
                  <button class="btn btn-ghost" type="button" @click="cancelManual">Cancel</button>
                </div>
              </div>
            </details>
          </div>
        </div>

        <!-- Steps and About -->
        <div class="grid gap-6 md:grid-cols-2">
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h3 class="card-title">Use in Stremio</h3>
              <ol class="list-decimal pl-6">
                <li>Open Stremio → Addons → Install via URL</li>
                <li>Paste your <span class="badge">Manifest URL</span> and install</li>
                <li>Click <b>Configure</b> and choose a variant or set a custom trackers URL</li>
              </ol>
              <div class="mt-2 space-y-1 text-sm opacity-80">
                <div>Pro tip: Leave custom URL empty to use the selected variant list.</div>
                <div>Changes apply instantly to new stream requests.</div>
              </div>
          </div>
        </div>

        <div class="card bg-base-200 shadow">
          <div class="card-body">
            <h3 class="card-title">About SeedSphere</h3>
            <p>SeedSphere augments magnet links with additional public trackers to help peers find each other faster — smoother playback, fewer stalls.</p>
          </div>
        </div>
      </div>
    </div>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from 'vue'
import { gardener } from '../lib/gardener'

const boosts = ref([])
const sseStatus = ref('waiting') // waiting | ok | warn | error
let es = null
let esSweep = null
const sweepStreaming = ref(false)
const sweepProgress = ref({ processed: 0, healthy: 0, total: 0 })

// Pairing state
const installId = ref('')
const pairCode = ref('')
const deviceId = ref('')
const pairingMsg = ref('')
const pairingMsgClass = computed(() => pairingMsg.value.includes('error') ? 'text-error' : 'opacity-70')
let pairStatusTimer = null

async function ensurePairing() {
  try {
    const existing = localStorage.getItem('seedsphere.install_id') || ''
    const existingCode = localStorage.getItem('seedsphere.pair_code') || ''
    if (existing) {
      installId.value = existing
      pairCode.value = existingCode
      pairingMsg.value = 'Pairing active. Share pair code with Seedling to complete.'
      return
    }
  } catch (_) {}
  try {
    const res = await fetch('/api/pair/start', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const j = await res.json()
    if (j && j.pair_code && j.install_id) {
      installId.value = j.install_id
      pairCode.value = j.pair_code
      try {
        localStorage.setItem('seedsphere.install_id', j.install_id)
        localStorage.setItem('seedsphere.pair_code', j.pair_code)
      } catch (_) {}
      pairingMsg.value = 'Pairing started. Waiting for Seedling to complete.'
      showToast('Pairing started', 'alert-info')
    } else {
      pairingMsg.value = 'error: invalid response when starting pairing'
      showToast('Failed to start pairing', 'alert-error')
    }
  } catch (e) {
    pairingMsg.value = `error: ${e?.message || 'network error'}`
    showToast('Failed to start pairing', 'alert-error')
  }
}

// --- AI gating helpers & UI refs ---
const showLoginOverlay = ref(false)
const presetMode = ref('balanced')
const aiCard = ref(null)
const keysSection = ref(null)
const srvApiKeyInput = ref(null)

function hasServerKey(provider) {
  try {
    const p = String(provider || '').toLowerCase()
    return Array.isArray(srvKeys.value) && srvKeys.value.some(k => String(k?.provider || '').toLowerCase() === p)
  } catch { return false }
}

async function goManageKeysFor(provider) {
  try { srvProvider.value = provider } catch (_) {}
  try { await nextTick() } catch (_) {}
  try { keysSection?.value?.scrollIntoView({ behavior: 'smooth', block: 'start' }) } catch (_) {}
  // focus input a bit later so scroll can start
  try { setTimeout(() => { try { srvApiKeyInput?.value?.focus() } catch (_) {} }, 400) } catch (_) {}
}

function onToggleAi(e) {
  const checked = !!(e && e.target && e.target.checked)
  if (checked) {
    if (!sessionUserId.value) {
      showLoginOverlay.value = true
      try { e.target.checked = false } catch (_) {}
      return
    }
    if (!hasServerKey(aiProvider.value)) {
      showToast('Save a server key first for the selected provider', 'warning')
      try { e.target.checked = false } catch (_) {}
      goManageKeysFor(aiProvider.value)
      return
    }
    aiEnabled.value = true
  } else {
    aiEnabled.value = false
  }
}

function onProviderChange() {
  if (aiEnabled.value && !hasServerKey(aiProvider.value)) {
    showToast(`No server key for ${aiProvider.value}. Manage it below.`, 'warning')
  }
}

function applyAiPreset() {
  const m = String(presetMode.value || 'balanced')
  if (m === 'fast') {
    aiProvider.value = 'openai'
    aiModel.value = 'gpt-4o-mini'
    aiTimeoutMs.value = 2000
    aiCacheTtlMs.value = 30000
  } else if (m === 'rich') {
    aiProvider.value = 'openai'
    aiModel.value = 'gpt-4.1'
    aiTimeoutMs.value = 4000
    aiCacheTtlMs.value = 120000
  } else {
    // balanced default
    aiProvider.value = 'openai'
    aiModel.value = 'gpt-4o'
    aiTimeoutMs.value = 2500
    aiCacheTtlMs.value = 60000
  }
}

// Session: fetch current user to include ai_user_id in share links
const sessionUserId = ref('')
async function fetchSession() {
  try {
    const res = await fetch('/api/auth/session')
    if (!res.ok) return
    const data = await res.json()
    const uid = data && data.user && data.user.id ? String(data.user.id) : ''
    sessionUserId.value = uid
  } catch (_) { /* ignore */ }
}
onMounted(() => {
  fetchSession()
  ensurePairing()
  try {
    fetchPairStatus()
    pairStatusTimer = setInterval(fetchPairStatus, 15000)
  } catch (_) {}
})

onBeforeUnmount(() => {
  try { pairStatusTimer && clearInterval(pairStatusTimer) } catch (_) {}
  try { es && es.close() } catch (_) {};
  try { esSweep && esSweep.close() } catch (_) {}
})

// Account & AI Keys (server) state
const magicEmail = ref('')
const srvProvider = ref('openai')
const srvApiKey = ref('')
const srvKeys = ref([])

async function refreshSrvKeys() {
  try {
    const res = await fetch('/api/keys/list')
    if (!res.ok) {
      if (res.status === 401) { srvKeys.value = []; return }
      throw new Error(`HTTP ${res.status}`)
    }
    const data = await res.json()
    srvKeys.value = Array.isArray(data?.items) ? data.items : []
  } catch (_) { srvKeys.value = [] }
}

async function saveKeyServer() {
  try {
    if (!sessionUserId.value) { showToast('Sign in first', 'warning'); return }
    const payload = { provider: srvProvider.value, key: srvApiKey.value }
    const res = await fetch('/api/keys/set', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
    const ok = res.ok
    if (!ok) {
      const j = await res.json().catch(() => ({}))
      throw new Error(j?.error || `HTTP ${res.status}`)
    }
    srvApiKey.value = ''
    await refreshSrvKeys()
    showToast('Saved', 'success')
  } catch (e) { showToast(`Save failed: ${e?.message || 'error'}`, 'error') }
}

async function deleteKeyServer(provider) {
  try {
    const res = await fetch(`/api/keys/${encodeURIComponent(provider)}`, { method: 'DELETE' })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    await refreshSrvKeys()
    showToast('Deleted', 'success')
  } catch (e) { showToast(`Delete failed: ${e?.message || 'error'}`, 'error') }
}

async function startMagicLink() {
  try {
    const email = String(magicEmail.value || '').trim()
    if (!email) { showToast('Enter your email', 'warning'); return }
    const res = await fetch('/api/auth/magic/start', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email }) })
    if (!res.ok) {
      const j = await res.json().catch(() => ({}))
      throw new Error(j?.error || `HTTP ${res.status}`)
    }
    showToast('Check your email for the sign-in link', 'success')
  } catch (e) { showToast(`Magic link failed: ${e?.message || 'error'}`, 'error') }
}

async function logout() {
  try {
    const res = await fetch('/api/auth/logout', { method: 'POST' })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    sessionUserId.value = ''
    await refreshSrvKeys()
    showToast('Signed out', 'success')
  } catch (e) { showToast(`Logout failed: ${e?.message || 'error'}`, 'error') }
}

onMounted(() => { refreshSrvKeys() })

function connectSse() {
  try {
    sseStatus.value = 'waiting'
    es = new EventSource('/api/boosts/events')
    es.onopen = () => { sseStatus.value = 'ok' }
    es.addEventListener('snapshot', (e) => {
      try { const data = JSON.parse(e.data); boosts.value = data.items || []; sseStatus.value = 'ok' } catch (_) { sseStatus.value = 'warn' }
    })
    es.addEventListener('boost', (e) => {
      try { const it = JSON.parse(e.data); boosts.value = [it, ...boosts.value].slice(0, 200); sseStatus.value = 'ok' } catch (_) { sseStatus.value = 'warn' }
    })
    es.onerror = () => { sseStatus.value = 'error' }
  } catch (_) { /* ignore */ }
}

function fmtTime(ts) {
  try { return new Date(ts).toLocaleString() } catch { return '' }
}

onMounted(connectSse)
onBeforeUnmount(() => { try { es && es.close() } catch (_) {}; try { esSweep && esSweep.close() } catch (_) {} })

// Sweep & Validate tools
const origin = typeof window !== 'undefined' ? window.location.origin : ''
const manifestHttp = computed(() => {
  try {
    const u = new URL('/manifest.json', origin || 'http://localhost')
    const gid = gardener.getGardenerId()
    if (gid) u.searchParams.set('gardener_id', gid)
    return u.toString()
  } catch (_) { return `${origin}/manifest.json` }
})
// Version-aware stremio deep link; fallback to plain protocol if no version
const latestVersion = ref('')
const seenVersion = ref('')
function cmpSemver(a, b) {
  try {
    const pa = String(a || '').split('.')
    const pb = String(b || '').split('.')
    for (let i = 0; i < 3; i++) {
      const na = parseInt(pa[i] || '0', 10)
      const nb = parseInt(pb[i] || '0', 10)
      if (Number.isNaN(na) || Number.isNaN(nb)) break
      if (na > nb) return 1
      if (na < nb) return -1
    }
    return 0
  } catch (_) { return 0 }
}
// Show only when server version is strictly greater than last seen
const showUpdateBanner = computed(() => {
  if (!latestVersion.value) return false
  if (!seenVersion.value) return false
  return cmpSemver(latestVersion.value, seenVersion.value) > 0
})
const manifestProtocol = computed(() => {
  const url = encodeURIComponent(manifestHttp.value)
  const v = latestVersion.value
  if (v) return `stremio://addon-install?url=${url}&version=${encodeURIComponent(v)}`
  return `stremio://${url}`
})

const url = ref('')
const variant = ref('all')
const mode = ref('basic')
const limitEnabled = ref(false)
const limit = ref(0)
const full = ref(false)
const busy = ref(false)
const error = ref('')
const result = ref(null)
const validateMsg = ref('')
const validateOk = ref(false)

const allowlist = ref('')
const blocklist = ref('')

const busyHealth = ref(false)
const healthMsg = ref('')
const healthData = ref(null)
const healthRaw = ref(null)
const showAdvancedHealth = ref(false)
const quickMsg = ref('')
const quickData = ref(null)
const quickRaw = ref(null)
const showAdvancedQuick = ref(false)
const quickList = ref([])
const lastPreset = ref('')
const lastSweepList = ref([])
const filteredSweepList = computed(() => applyAllowBlock(lastSweepList.value))

// Description & AI settings (frontend state mirrors addon config keys)
const descAppendOriginal = ref(false) // addon default: off
const descRequireDetails = ref(true)  // addon default: on
const aiEnabled = ref(false)          // addon default: off
const AI_PROVIDER_OPTIONS = ['openai', 'anthropic', 'google', 'azure']
const aiProvider = ref('openai')
const aiModel = ref('gpt-4o')
const aiTimeoutMs = ref(2500)
const aiCacheTtlMs = ref(60000)
const aiApiKey = ref('')     // local-only, not serialized
const aiBaseUrl = ref('')    // local-only, for azure
const aiAzureApiVersion = ref('2024-06-01') // local-only, for azure
// LocalStorage keys for AI settings
const LS_AI_LOCAL = 'seedsphere.ai.local'          // secrets: apiKey, azure base url, api version
const LS_AI_STATE = 'seedsphere.ai.state'          // non-secrets: enabled, provider, model, timeouts

const availableAiModels = computed(() => {
  switch (aiProvider.value) {
    case 'anthropic':
      return [
        // Claude 4 series (examples)
        'claude-4-opus',
        'claude-4-sonnet',
        'claude-4-haiku',
        // Stable aliases
        'claude-4-opus-latest',
        'claude-4-sonnet-latest',
        'claude-4-haiku-latest',
        // Common previous family aliases
        'claude-3-5-sonnet',
        'claude-3-5-haiku',
      ]
    case 'google':
      return [
        'gemini-2.5-pro',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
        // Fallbacks
        'gemini-1.5-pro',
        'gemini-1.5-flash',
      ]
    case 'azure':
      return ['azure-deployment']
    case 'openai':
    default:
      return [
        // GPT-5 family (examples)
        'gpt-5',
        'gpt-5-mini',
        'gpt-5-nano',
        // Current widely used
        'gpt-4.1',
        'gpt-4.1-mini',
        'gpt-4o',
        'gpt-4o-mini',
        'o3-mini',
      ]
  }
})

watch(aiProvider, (p) => {
  const models = availableAiModels.value
  if (!models.includes(aiModel.value)) aiModel.value = models[0]
})

// Persist local-only AI credentials/settings
// LS_AI_LOCAL declared above; avoid redeclaration
onMounted(() => {
  try {
    const saved = JSON.parse(localStorage.getItem(LS_AI_LOCAL) || '{}')
    if (saved && typeof saved === 'object') {
      if (typeof saved.aiApiKey === 'string') aiApiKey.value = saved.aiApiKey
      if (typeof saved.aiBaseUrl === 'string') aiBaseUrl.value = saved.aiBaseUrl
      if (typeof saved.aiAzureApiVersion === 'string') aiAzureApiVersion.value = saved.aiAzureApiVersion
    }
  } catch (_) {}
})

watch([aiApiKey, aiBaseUrl, aiAzureApiVersion], () => {
  try {
    localStorage.setItem(LS_AI_LOCAL, JSON.stringify({
      aiApiKey: aiApiKey.value,
      aiBaseUrl: aiBaseUrl.value,
      aiAzureApiVersion: aiAzureApiVersion.value,
    }))
  } catch (_) {}
}, { deep: true })

// Persist non-secret AI UI state for convenience
onMounted(() => {
  try {
    const saved = JSON.parse(localStorage.getItem(LS_AI_STATE) || '{}')
    if (saved && typeof saved === 'object') {
      if (typeof saved.aiEnabled === 'boolean') aiEnabled.value = saved.aiEnabled
      if (typeof saved.aiProvider === 'string') aiProvider.value = saved.aiProvider
      if (typeof saved.aiModel === 'string') aiModel.value = saved.aiModel
      if (typeof saved.aiTimeoutMs === 'number') aiTimeoutMs.value = saved.aiTimeoutMs
      if (typeof saved.aiCacheTtlMs === 'number') aiCacheTtlMs.value = saved.aiCacheTtlMs
    }
  } catch (_) {}
})

watch([aiEnabled, aiProvider, aiModel, aiTimeoutMs, aiCacheTtlMs], () => {
  try {
    localStorage.setItem(LS_AI_STATE, JSON.stringify({
      aiEnabled: !!aiEnabled.value,
      aiProvider: aiProvider.value,
      aiModel: aiModel.value,
      aiTimeoutMs: Number(aiTimeoutMs.value) || 0,
      aiCacheTtlMs: Number(aiCacheTtlMs.value) || 0,
    }))
  } catch (_) {}
}, { deep: true })

const recentBoosts = ref([])
const boostsMetrics = computed(() => {
  if (!recentBoosts.value.length) return 'No data.'
  const total = recentBoosts.value.length
  const sums = recentBoosts.value.reduce((acc, b) => ({
    healthy: acc.healthy + (b.healthy || 0),
    total: acc.total + (b.total || 0),
  }), { healthy: 0, total: 0 })
  return `Items: ${total}\nHealthy sum: ${sums.healthy}\nTotal sum: ${sums.total}`
})

function pretty(v) { try { return JSON.stringify(v, null, 2) } catch { return String(v) } }

// Simple toast
const toastMsg = ref('')
const toastType = ref('alert-info')
let toastTimer = null
function showToast(msg, type = 'info', ms = 1500) {
  toastMsg.value = msg
  toastType.value = type === 'success' ? 'alert-success' : type === 'error' ? 'alert-error' : type === 'warning' ? 'alert-warning' : 'alert-info'
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastMsg.value = '' }, ms)
}

function copy(text) {
  try { navigator.clipboard.writeText(text); showToast('Copied', 'success') } catch (_) { showToast('Copy failed', 'error') }
}

function hostnameOf(u) {
  try { return new URL(u).hostname.toLowerCase() } catch { return '' }
}

function parseList(text) {
  return (text || '').split(/\r?\n/).map(s => s.trim().toLowerCase()).filter(Boolean)
}

function matchesHost(host, rule) {
  // simple contains or exact match
  return host === rule || host.endsWith(`.${rule}`)
}

function applyAllowBlock(list) {
  const allow = parseList(allowlist.value)
  const block = parseList(blocklist.value)
  const filtered = []
  for (const t of Array.isArray(list) ? list : []) {
    const h = hostnameOf(t)
    if (!h) continue
    if (allow.length && !allow.some(r => matchesHost(h, r))) continue
    if (block.length && block.some(r => matchesHost(h, r))) continue
    filtered.push(t)
  }
  return filtered
}

// Apply allow/block explicitly to provide feedback
function applyAllowBlockNow() {
  try {
    // trigger recompute usage sites (filtered preview already reactive)
    lastSweepList.value = [...lastSweepList.value]
    showToast('Allow/Block applied', 'success')
  } catch (_) { showToast('Apply failed', 'error') }
}

// Map variant -> canonical NGO list URL (backup-compatible)
function variantToUrl(v) {
  const name = String(v || 'all').toLowerCase()
  switch (name) {
    case 'best': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt'
    case 'all_udp': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_udp.txt'
    case 'all_http': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_http.txt'
    case 'all_https': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_https.txt'
    case 'all_ws': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ws.txt'
    case 'all_i2p': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_i2p.txt'
    case 'all_ip': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt'
    case 'best_ip': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt'
    case 'all':
    default: return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt'
  }
}

async function runSweep() {
  error.value = ''
  result.value = null
  sweepStats.value = null
  sweepMerged.value = []
  busy.value = true
  try {
    // Close previous stream if any
    try { esSweep && esSweep.close() } catch (_) {}
    const src = (url.value || '').trim() || variantToUrl(variant.value)
    const u = new URL('/api/trackers/sweep/stream', window.location.origin)
    u.searchParams.set('url', src)
    u.searchParams.set('mode', mode.value)
    if (limitEnabled.value && Number(limit.value) >= 0) u.searchParams.set('limit', String(limit.value))
    // Force full list so we can merge properly after
    u.searchParams.set('full', '1')
    sweepStreaming.value = true
    sweepProgress.value = { processed: 0, healthy: 0, total: 0 }
    await new Promise((resolve) => {
      esSweep = new EventSource(u.toString())
      esSweep.addEventListener('init', (e) => {
        try { const d = JSON.parse(e.data); sweepProgress.value.total = Number(d.total || 0) } catch (_) {}
        // Clear transient warning on successful init
        if (error.value && /connection unstable/i.test(error.value)) error.value = ''
      })
      esSweep.addEventListener('progress', (e) => {
        try {
          const d = JSON.parse(e.data)
          sweepProgress.value = {
            processed: Number(d.processed || 0),
            healthy: Number(d.healthy || 0),
            total: Number(d.total || sweepProgress.value.total || 0),
          }
        } catch (_) {}
        // Clear transient warning on healthy progress
        if (error.value && /connection unstable/i.test(error.value)) error.value = ''
      })
      esSweep.addEventListener('final', (e) => {
        try {
          const data = JSON.parse(e.data)
          result.value = data
          const incoming = Array.isArray(data?.list) ? data.list : (Array.isArray(data?.sample) ? data.sample : [])
          lastSweepList.value = incoming
          const filtered = applyAllowBlock(incoming)
          const modeMerge = manualMergeMode.value || 'append'
          let merged = []
          if (modeMerge === 'replace') {
            merged = filtered.slice()
            manualStaged.value = merged.slice()
          } else {
            const set = new Set(manualStaged.value)
            for (const t of filtered) set.add(t)
            merged = Array.from(set)
          }
          if (manualAutoSave.value) saveManual()
          sweepMerged.value = merged
          const total = Number(data?.total || incoming.length || 0)
          const healthy = Number(data?.healthy || filtered.length || 0)
          const pct = total ? Math.round((healthy / total) * 100) : 0
          sweepStats.value = { healthy, total, pct, mode: mode.value, limit: (limitEnabled.value ? Number(limit.value) || 0 : 0), merged: merged.length }
        } catch (err) {
          error.value = err?.message || 'Sweep failed'
        } finally {
          try { esSweep && esSweep.close() } catch (_) {}
          esSweep = null
          sweepStreaming.value = false
          resolve()
        }
      })
      esSweep.addEventListener('error', (e) => {
        // Transient network hiccups trigger 'error'; EventSource will auto-reconnect.
        // Do NOT close or resolve here; keep the progress UI visible.
        // Optionally show a soft warning without interrupting the sweep.
        if (!error.value) error.value = 'Sweep connection unstable, attempting to reconnect…'
        // If the server emits an error event with data, we still keep the stream open
        // to allow potential retry logic server-side.
        try {
          if (e && e.data) {
            const d = JSON.parse(e.data)
            if (d && d.error) error.value = String(d.error)
          }
        } catch (_) { /* ignore parse errors */ }
      })
      // Safety: if onopen never fires, still resolve after some time
      esSweep.onopen = () => { if (error.value && /connection unstable/i.test(error.value)) error.value = '' }
    })
  } catch (e) {
    error.value = e?.message || 'Sweep failed'
  } finally { busy.value = false; quickRunning.value = false }
}

async function runValidate() {
  validateMsg.value = ''
  validateOk.value = false
  if (!url.value) { validateMsg.value = 'Please enter a URL'; return }
  busy.value = true
  try {
    const u = new URL('/api/validate', window.location.origin)
    u.searchParams.set('url', url.value)
    const res = await fetch(u)
    const data = await res.json()
    validateOk.value = !!data && !data.error
    validateMsg.value = validateOk.value ? 'Custom URL looks valid.' : (data.error || 'Validate failed')
    result.value = data
  } catch (e) {
    validateMsg.value = e.message || 'Validate failed'
  } finally { busy.value = false }
}

const quickRunning = ref(false)
async function quickSweep() {
  busy.value = true
  quickRunning.value = true
  quickData.value = null
  try {
    const u = new URL('/api/trackers/sweep', window.location.origin)
    if (url.value) u.searchParams.set('url', url.value)
    else u.searchParams.set('variant', variant.value)
    u.searchParams.set('mode', mode.value)
    if (limitEnabled.value) u.searchParams.set('limit', String(limit.value))
    if (full.value) u.searchParams.set('full', '1')
    
    // eslint-disable-next-line no-await-in-loop
    const res = await fetch(u)
    const data = await res.json()
    quickRaw.value = data
    // Summarize for UI chips
    quickData.value = {
      total: Number(data?.total || 0),
      healthy: Number(data?.healthy || 0),
      mode: String(data?.mode || ''),
      limit: Number(data?.limit || 0),
    }

    // Determine list from server and apply filter
    const incoming = Array.isArray(data?.list) ? data.list : (Array.isArray(data?.sample) ? data.sample : [])
    const filtered = applyAllowBlock(incoming)
    quickList.value = filtered

    // Optionally merge into manual list
    if (manualAutoSave.value) {
      mergeManualFrom(filtered)
      saveManual()
    }
  } catch (_) {
    quickData.value = null
  } finally { busy.value = false }
}

async function copyQuickDiagnostics() {
  try {
    const payload = quickRaw.value ?? {}
    await navigator.clipboard.writeText(JSON.stringify(payload, null, 2))
  } catch (_) { /* ignore */ }
}

function applyPreset(name) {
  if (name === 'default') {
    variant.value = 'all'
    url.value = ''
    mode.value = 'basic'
    limitEnabled.value = false
    limit.value = 0
    full.value = false
    lastPreset.value = 'default'
  } else if (name === 'minimal') {
    variant.value = 'best'
    url.value = ''
    mode.value = 'off'
    limitEnabled.value = true
    limit.value = 25
    full.value = false
    lastPreset.value = 'minimal'
  } else if (name === 'aggressive') {
    variant.value = 'all_udp'
    url.value = ''
    mode.value = 'aggressive'
    limitEnabled.value = false
    limit.value = 0
    full.value = true
    lastPreset.value = 'aggressive'
  }
}

async function copyShareLink() {
  try {
    const u = new URL(window.location.href)
    if (url.value) {
      u.searchParams.set('url', url.value)
      u.searchParams.set('trackers_url', url.value)
    } else {
      u.searchParams.set('variant', variant.value)
    }
    u.searchParams.set('mode', mode.value)
  if (limitEnabled.value) {
    u.searchParams.set('limit', String(limit.value))
    u.searchParams.set('limit_enable', '1')
    u.searchParams.set('max_trackers', String(limit.value))
  }
  u.searchParams.set('auto_proxy', autoProxy.value ? 'on' : 'off')
  // Provider toggles -> addon config keys
  try {
    const map = PROVIDER_CONFIG_MAP || {}
    for (const [name, enabled] of Object.entries(providersEnabled.value || {})) {
      const key = map[name]
      if (key) u.searchParams.set(key, enabled ? 'on' : 'off')
    }
  } catch (_) { /* ignore */ }
  // Description & AI toggles -> addon config keys
  u.searchParams.set('desc_append_original', descAppendOriginal.value ? 'on' : 'off')
  u.searchParams.set('desc_require_details', descRequireDetails.value ? 'on' : 'off')
  u.searchParams.set('ai_descriptions', aiEnabled.value ? 'on' : 'off')
  u.searchParams.set('ai_provider', aiProvider.value)
  u.searchParams.set('ai_model', aiModel.value)
  u.searchParams.set('ai_timeout_ms', String(aiTimeoutMs.value))
  u.searchParams.set('ai_cache_ttl_ms', String(aiCacheTtlMs.value))
  // Include ai_user_id when logged in
  if (sessionUserId.value) u.searchParams.set('ai_user_id', sessionUserId.value)
  if (full.value) u.searchParams.set('full', '1')
  if (lastPreset.value) u.searchParams.set('preset', lastPreset.value)
  if (allowlist.value) u.searchParams.set('allowlist', allowlist.value)
  if (blocklist.value) u.searchParams.set('blocklist', blocklist.value)
    const text = u.toString()
    await navigator.clipboard.writeText(text)
    showToast('Share link copied', 'success')
  } catch (_) { showToast('Copy failed', 'error') }
}

async function checkHealth() {
  busyHealth.value = true
  healthData.value = null
  try {
    const res = await fetch('/api/trackers/health')
    const data = await res.json()
    healthRaw.value = data
    // Expecting shape with counts; fall back safely
    const total = Number(data?.total ?? data?.size ?? data?.count ?? 0)
    const healthy = Number(data?.ok ?? data?.healthy ?? 0)
    const unhealthy = Number(data?.bad ?? data?.unhealthy ?? Math.max(0, total - healthy))
    // Derive latest update from sample timestamps when available
    const sample = Array.isArray(data?.sample) ? data.sample : []
    const latestTs = sample.reduce((m, it) => {
      const t = Number(it?.ts || 0)
      return Number.isFinite(t) && t > m ? t : m
    }, 0)
    healthData.value = {
      size: total,
      healthy,
      unhealthy,
      updated_ts: latestTs || Date.now(),
    }
  } catch (_) {
    healthData.value = null
  } finally { busyHealth.value = false }
}

async function copyHealthDiagnostics() {
  try {
    const payload = healthRaw.value ?? {}
    await navigator.clipboard.writeText(JSON.stringify(payload, null, 2))
    showToast('Diagnostics copied', 'success')
  } catch (_) { showToast('Copy failed', 'error') }
}

async function loadRecentBoosts() {
  try {
    const res = await fetch('/api/boosts/recent')
    const data = await res.json()
    recentBoosts.value = Array.isArray(data?.items) ? data.items : []
  } catch (_) { recentBoosts.value = [] }
}

onMounted(() => { loadRecentBoosts() })

// Health/version for update banner and deep link version
onMounted(async () => {
  try {
    seenVersion.value = localStorage.getItem('seedsphere.version_seen') || ''
  } catch (_) {}
  try {
    const res = await fetch('/health')
    const data = await res.json()
    if (data && typeof data.version === 'string') {
      latestVersion.value = data.version
      try { localStorage.setItem('seedsphere.version_latest', data.version) } catch (_) {}
      // Initialize seen version on first load to avoid false-positive banner
      try {
        if (!seenVersion.value) {
          localStorage.setItem('seedsphere.version_seen', data.version)
          seenVersion.value = data.version
        }
      } catch (_) {}
    }
  } catch (_) {}
})

function dismissUpdate() {
  try {
    if (latestVersion.value) localStorage.setItem('seedsphere.version_seen', latestVersion.value)
    seenVersion.value = latestVersion.value
  } catch (_) {}
}

// Manual trackers: state
const LS_KEY = 'seedsphere.manualTrackers'
const manualSaved = ref([])
const manualStaged = ref([])
const manualNew = ref('')
const manualStrict = ref(false)
const manualMergeMode = ref('append') // or 'replace'
const manualAutoSave = ref(false)

function loadManual() {
  try {
    const raw = localStorage.getItem(LS_KEY)
    const arr = raw ? JSON.parse(raw) : []
    manualSaved.value = Array.isArray(arr) ? arr : []
  } catch { manualSaved.value = [] }
  manualStaged.value = [...manualSaved.value]
}

function cleanRows(rows) {
  // Trim, remove empties and duplicates
  const seen = new Set()
  const out = []
  for (const r of rows.map(r => (r || '').trim())) {
    if (!r) continue
    if (seen.has(r)) continue
    seen.add(r)
    out.push(r)
  }
  return out
}

function addManualRow() {
  const v = (manualNew.value || '').trim()
  if (!v) return
  manualStaged.value.push(v)
  manualNew.value = ''
}

function removeManualRow(i) {
  manualStaged.value.splice(i, 1)
}

function revertManual() {
  manualStaged.value = [...manualSaved.value]
}

function cancelManual() {
  manualStaged.value = [...manualSaved.value]
}

function saveManual() {
  const rows = cleanRows(manualStaged.value)
  if (manualStrict.value) {
    // Basic sanity: must look like a URL with protocol
    for (const r of rows) {
      try { new URL(r) } catch { return }
    }
  }
  manualSaved.value = rows
  try { localStorage.setItem(LS_KEY, JSON.stringify(rows)) } catch {}
}

function mergeManualFrom(list) {
  const incoming = cleanRows(list)
  if (manualMergeMode.value === 'replace') {
    manualStaged.value = [...incoming]
  } else {
    // append unique
    const set = new Set(manualStaged.value)
    for (const item of incoming) if (!set.has(item)) manualStaged.value.push(item)
  }
}

async function importManual() {
  const pasted = prompt('Paste trackers (one per line):')
  if (pasted == null) return
  const list = pasted.split(/\r?\n/).map(s => s.trim()).filter(Boolean)
  mergeManualFrom(list)
}

function exportManual() {
  const blob = new Blob([manualStaged.value.join('\n')], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'trackers.txt'
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

function downloadMerged() {
  const blob = new Blob([quickList.value.join('\n')], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'trackers-merged.txt'
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

function copyFiltered() {
  try { navigator.clipboard.writeText(filteredSweepList.value.join('\n')); showToast('Filtered copied', 'success') } catch (_) { showToast('Copy failed', 'error') }
}

function downloadFiltered() {
  const blob = new Blob([filteredSweepList.value.join('\n')], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'trackers-filtered.txt'
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

onMounted(() => { loadManual() })

// Persist and restore UI state
onMounted(() => {
  try {
    const saved = JSON.parse(localStorage.getItem('seedsphere.configure') || '{}')
    if (saved && typeof saved === 'object') {
      if (saved.variant) variant.value = saved.variant
      if (typeof saved.url === 'string') url.value = saved.url
      if (saved.mode) mode.value = saved.mode
      if (typeof saved.limitEnabled === 'boolean') limitEnabled.value = saved.limitEnabled
      if (typeof saved.limit === 'number') limit.value = saved.limit
      if (typeof saved.full === 'boolean') full.value = saved.full
      if (typeof saved.autoProxy === 'boolean') autoProxy.value = saved.autoProxy
      if (typeof saved.allowlist === 'string') allowlist.value = saved.allowlist
      if (typeof saved.blocklist === 'string') blocklist.value = saved.blocklist
      if (typeof saved.lastPreset === 'string') lastPreset.value = saved.lastPreset
    }
  } catch (_) {}

  try {
    const savedManual = JSON.parse(localStorage.getItem('seedsphere.manualOptions') || '{}')
    if (savedManual && typeof savedManual === 'object') {
      if (savedManual.manualStrict != null) manualStrict.value = !!savedManual.manualStrict
      if (savedManual.manualMergeMode) manualMergeMode.value = savedManual.manualMergeMode
      if (savedManual.manualAutoSave != null) manualAutoSave.value = !!savedManual.manualAutoSave
    }
  } catch (_) {}
})

watch([variant, url, mode, limitEnabled, limit, full, allowlist, blocklist, lastPreset], () => {
  try {
    localStorage.setItem('seedsphere.configure', JSON.stringify({
      variant: variant.value,
      url: url.value,
      mode: mode.value,
      limitEnabled: !!limitEnabled.value,
      limit: Number(limit.value) || 0,
      full: !!full.value,
      autoProxy: !!autoProxy.value,
      allowlist: allowlist.value,
      blocklist: blocklist.value,
      lastPreset: lastPreset.value,
    }))
  } catch (_) {}
}, { deep: true })

watch([manualStrict, manualMergeMode, manualAutoSave], () => {
  try {
    localStorage.setItem('seedsphere.manualOptions', JSON.stringify({
      manualStrict: !!manualStrict.value,
      manualMergeMode: manualMergeMode.value,
      manualAutoSave: !!manualAutoSave.value,
    }))
  } catch (_) {}
})

// Manual validation helpers
function isValidTracker(v) {
  try {
    const u = new URL(v)
    return ['udp:', 'http:', 'https:', 'ws:', 'wss:'].includes(u.protocol)
  } catch { return false }
}

const manualHasInvalid = computed(() => {
  return manualStaged.value.some(x => x && !isValidTracker(x))
})

// Sweep UI state
const sweepStats = ref(null)
const sweepMerged = ref([])

// Upstream Proxy toggle (mirrors addon config "auto_proxy")
const autoProxy = ref(true)

function downloadSweepMerged() {
  const blob = new Blob([sweepMerged.value.join('\n')], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'trackers-merged.txt'
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

// Providers detection
const providers = ref([])
const providersFetchedAt = ref(0)
const busyProviders = ref(false)
// Provider enablement state (UI-level). Persisted locally and exported via share link to addon config.
const providersEnabled = ref({}) // { [providerName: string]: boolean }
const LS_PROVIDERS_KEY = 'seedsphere.providers.enabled'
// Map UI provider name to addon config key
const PROVIDER_CONFIG_MAP = {
  Torrentio: 'providers_torrentio',
  YTS: 'providers_yts',
  EZTV: 'providers_eztv',
  Nyaa: 'providers_nyaa',
  '1337x': 'providers_1337x',
  'Pirate Bay': 'providers_piratebay',
  TorrentGalaxy: 'providers_torrentgalaxy',
  Torlock: 'providers_torlock',
  MagnetDL: 'providers_magnetdl',
  AniDex: 'providers_anidex',
  TokyoTosho: 'providers_tokyotosho',
  Zooqle: 'providers_zooqle',
  Rutor: 'providers_rutor',
}
async function detectProviders() {
  busyProviders.value = true
  try {
    const res = await fetch('/api/providers/detect')
    const data = await res.json()
    providers.value = Array.isArray(data?.providers) ? data.providers : []
    providersFetchedAt.value = Date.now()
  } catch (_) { providers.value = [] }
  finally { busyProviders.value = false }
}
onMounted(() => { detectProviders() })

const providerCategoryMap = {
  Torrentio: 'Torrent Aggregators',
  YTS: 'Movies',
  EZTV: 'Series',
  Nyaa: 'Anime',
  '1337x': 'Torrent Aggregators',
  'Pirate Bay': 'Torrent Aggregators',
  TorrentGalaxy: 'Torrent Aggregators',
  Torlock: 'Torrent Aggregators',
  MagnetDL: 'Torrent Aggregators',
  AniDex: 'Anime',
  TokyoTosho: 'Anime',
  Zooqle: 'Torrent Aggregators',
  Rutor: 'Torrent Aggregators',
}

const groupedProviders = computed(() => {
  const groups = {
    'Torrent Aggregators': [],
    'Movies': [],
    'Series': [],
    'Anime': [],
    'Other': [],
  }
  for (const p of (providers.value || [])) {
    const cat = providerCategoryMap[p.name] || 'Other'
    groups[cat].push(p)
  }
  const order = ['Torrent Aggregators', 'Movies', 'Series', 'Anime', 'Other']
  return order.map(title => ({ title, items: groups[title].slice() }))
})

function providerTooltip(p) {
  const ts = providersFetchedAt.value ? fmtTime(providersFetchedAt.value) : 'n/a'
  const ms = (p && typeof p.ms === 'number') ? `${p.ms} ms` : 'n/a'
  return `Probed: ${ts} • Response: ${ms}`
}

function isProviderEnabled(name) {
  const v = providersEnabled.value[name]
  return v == null ? true : !!v
}

function toggleProvider(name, enabled) {
  providersEnabled.value = { ...providersEnabled.value, [name]: !!enabled }
  try { localStorage.setItem(LS_PROVIDERS_KEY, JSON.stringify(providersEnabled.value)) } catch (_) {}
}

// Credentialed providers (local-only)
const LS_CRED_ENABLED = 'seedsphere.providers.cred.enabled'
const LS_CRED_DATA = 'seedsphere.providers.cred.data'
const credentialedEnabled = ref({ Torznab: false, RealDebrid: false, AllDebrid: false, Orion: false })
const credentialedData = ref({ Torznab: [], RealDebrid: { token: '' }, AllDebrid: { apiKey: '' }, Orion: { apiKey: '', userId: '' } })

function loadCredentialed() {
  try {
    const e = JSON.parse(localStorage.getItem(LS_CRED_ENABLED) || '{}')
    if (e && typeof e === 'object') credentialedEnabled.value = { ...credentialedEnabled.value, ...e }
  } catch (_) {}
  try {
    const d = JSON.parse(localStorage.getItem(LS_CRED_DATA) || '{}')
    if (d && typeof d === 'object') credentialedData.value = { ...credentialedData.value, ...d }
  } catch (_) {}
}

function saveCredentialed() {
  try { localStorage.setItem(LS_CRED_ENABLED, JSON.stringify(credentialedEnabled.value)) } catch (_) {}
  try { localStorage.setItem(LS_CRED_DATA, JSON.stringify(credentialedData.value)) } catch (_) {}
}

function setCredentialedEnabled(name, enabled) {
  credentialedEnabled.value = { ...credentialedEnabled.value, [name]: !!enabled }
  saveCredentialed()
}

function addTorznabEndpoint() {
  const cur = Array.isArray(credentialedData.value.Torznab) ? credentialedData.value.Torznab.slice() : []
  cur.push({ url: '', apiKey: '' })
  credentialedData.value = { ...credentialedData.value, Torznab: cur }
  saveCredentialed()
}

function removeTorznabEndpoint(idx) {
  const cur = Array.isArray(credentialedData.value.Torznab) ? credentialedData.value.Torznab.slice() : []
  cur.splice(idx, 1)
  credentialedData.value = { ...credentialedData.value, Torznab: cur }
  saveCredentialed()
}

function updateTorznabEndpoint(idx, field, value) {
  const cur = Array.isArray(credentialedData.value.Torznab) ? credentialedData.value.Torznab.slice() : []
  if (!cur[idx]) return
  cur[idx] = { ...cur[idx], [field]: value }
  credentialedData.value = { ...credentialedData.value, Torznab: cur }
  saveCredentialed()
}

// Torznab connectivity tests (browser-side; may be limited by CORS)
const torznabTests = ref({})
async function testTorznabEndpoint(idx) {
  try {
    const ep = (credentialedData.value.Torznab || [])[idx]
    if (!ep || !ep.url) return
    torznabTests.value = { ...torznabTests.value, [idx]: { status: 'testing' } }
    const start = performance.now()
    const u = new URL(ep.url)
    if (ep.apiKey) u.searchParams.set('apikey', ep.apiKey)
    const res = await fetch(u.toString(), { method: 'GET' })
    const ms = Math.round(performance.now() - start)
    if (res.ok) torznabTests.value = { ...torznabTests.value, [idx]: { status: 'ok', ms } }
    else torznabTests.value = { ...torznabTests.value, [idx]: { status: 'error', ms, message: `HTTP ${res.status}` } }
  } catch (e) {
    torznabTests.value = { ...torznabTests.value, [idx]: { status: 'error', message: e?.message || 'Network error' } }
  }
}

function updateRealDebridField(field, value) {
  const cur = { ...(credentialedData.value.RealDebrid || { token: '' }) }
  cur[field] = value
  credentialedData.value = { ...credentialedData.value, RealDebrid: cur }
  saveCredentialed()
}

function updateAllDebridField(field, value) {
  const cur = { ...(credentialedData.value.AllDebrid || { apiKey: '' }) }
  cur[field] = value
  credentialedData.value = { ...credentialedData.value, AllDebrid: cur }
  saveCredentialed()
}

function updateOrionField(field, value) {
  const cur = { ...(credentialedData.value.Orion || { apiKey: '', userId: '' }) }
  cur[field] = value
  credentialedData.value = { ...credentialedData.value, Orion: cur }
  saveCredentialed()
}

onMounted(() => {
  try {
    const saved = JSON.parse(localStorage.getItem(LS_PROVIDERS_KEY) || '{}')
    if (saved && typeof saved === 'object') providersEnabled.value = saved
  } catch (_) {}
})

onMounted(() => { loadCredentialed() })

</script>

<style scoped>
.truncate { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
