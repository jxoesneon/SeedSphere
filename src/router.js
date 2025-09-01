import { createRouter, createWebHistory } from 'vue-router'

import Home from './pages/Home.vue'
import Configure from './pages/Configure.vue'

const routes = [
  { path: '/', name: 'home', component: Home },
  { path: '/configure', name: 'configure', component: Configure },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() { return { top: 0 } },
})

export default router
