<script setup>
import { defineAsyncComponent, ref, onMounted } from 'vue';
import NavigationMenu from '@/components/NavigationMenu.vue';
const PathSelector = defineAsyncComponent(() => import('@/components/PathSelector.vue'));
const SettingsView = defineAsyncComponent(() => import('@/views/SettingsView.vue'));
const FolderList = defineAsyncComponent(() => import('@/components/FolderList.vue'));
const LoraViewer = defineAsyncComponent(() => import('@/components/LoraViewer.vue'));
const FilterSidebar = defineAsyncComponent(() => import('@/components/FilterSidebar.vue'));

const showSelector = ref(false);
const selectorVisible = ref(false);
const currentPath = ref('/');
const isListExpanded = ref(true);
const isFilterExpanded = ref(true);
const loraFiles = ref([]);
const activeFilters = ref({
    versions: [],
    dims: [],
    alphas: []
});
const currentModule = ref('lora');  // 'lora' 或 'settings'

async function checkConfig() {
  const response = await fetch('http://localhost:5000/config');
  const config = await response.json();
  if (!config.lora_path) {
    showSelector.value = true;
    setTimeout(() => {
      selectorVisible.value = true;
    }, 100);
  }
}

async function handleConfirm(path) {
  await fetch('http://localhost:5000/config', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ lora_path: path })
  });

  selectorVisible.value = false;
  setTimeout(() => {
    showSelector.value = false;
  }, 500);
}

function handleFolderChange(path) {
  currentPath.value = path;
}

function handleExpandChange(expanded) {
  isListExpanded.value = expanded;
}

function handleFilterExpandChange(expanded) {
  isFilterExpanded.value = expanded;
}
function handleLoraFilesChange(files) {
    loraFiles.value = files;
}

function handleFilterChange(filters) {
    console.log('Received filters in App:', filters);
    activeFilters.value = filters;
}

function handleModuleChange(moduleId) {
    currentModule.value = moduleId;
}

onMounted(checkConfig);
</script>

<template>
  <Transition name="slide">
    <PathSelector v-if="showSelector" :class="{ visible: selectorVisible }" @confirm="handleConfirm" />
  </Transition>
  <div class="app-container">
    <!-- Lora 预览模块 -->
    <template v-if="currentModule === 'lora'">
      <FolderList 
        v-if="!showSelector" 
        @path-change="handleFolderChange" 
        @expand-change="handleExpandChange" 
      />
      <div class="main-content" :class="{
        'collapsed': showSelector,
        'list-collapsed': !isListExpanded,
        'filter-collapsed': !isFilterExpanded
      }">
        <LoraViewer 
          v-if="!showSelector"
          :current-path="currentPath"
          :is-expanded="isListExpanded"
          :is-filter-expanded="isFilterExpanded"
          :active-filters="activeFilters"
          @filter-expand-change="handleFilterExpandChange"
          @lora-files-change="handleLoraFilesChange"
        />
      </div>
      <FilterSidebar 
        v-if="!showSelector" 
        :is-expanded="isFilterExpanded"
        :lora-files="loraFiles"
        @expand-change="handleFilterExpandChange"
        @filter-change="handleFilterChange"
      />
    </template>

    <!-- 设置模块 -->
    <template v-else-if="currentModule === 'settings'">
      <SettingsView />
    </template>

    <!-- 导航菜单 -->
    <NavigationMenu 
      :current-module="currentModule"
      @module-change="handleModuleChange"
    />
  </div>
</template>

<style scoped>
.slide-enter-active,
.slide-leave-active {
  transition: transform 0.5s ease, opacity 0.5s ease;
}

.slide-enter-from,
.slide-leave-to {
  transform: translateY(-100%);
  opacity: 0;
}

.visible {
  transform: translateY(0);
  opacity: 1;
}

.app-container {
  display: flex;
  padding-bottom: 6rem; /* 为底部导航留出空间 */
}

.main-content {
  margin-left: 300px;
  margin-right: 300px;
  transition: all 0.3s ease;
}

.main-content.collapsed {
  margin-left: 40px;
}

.main-content.list-collapsed {
  margin-left: 40px;
}

.main-content.filter-collapsed {
  margin-right: 40px;
}
</style>
