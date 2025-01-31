<script setup>
import { defineAsyncComponent, ref, onMounted, watch } from 'vue';
import NavigationMenu from '@/components/NavigationMenu.vue';
const PathSelector = defineAsyncComponent(() => import('@/components/PathSelector.vue'));
const SettingsView = defineAsyncComponent(() => import('@/views/SettingsView.vue'));
const FolderList = defineAsyncComponent(() => import('@/components/FolderList.vue'));
const LoraViewer = defineAsyncComponent(() => import('@/components/LoraViewer.vue'));
const FilterSidebar = defineAsyncComponent(() => import('@/components/FilterSidebar.vue'));
const LoraCombinationView = defineAsyncComponent(() => import('@/views/LoraCombinationView.vue'));
import LoraDetail from './components/LoraDetail.vue';
import ImageDetail from './components/ImageDetail.vue';
import LoraSearchResult from './components/detailComp/LoraSearchResult.vue';
import { globalState } from './utils/globalVar';

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

function handleLoraDetailClose(index) {
    const detail = globalState.loraDetailStack.value[index];
    if (detail?.lora?.activeFilters) {
        // 恢复关闭前的筛选状态
        activeFilters.value = detail.lora.activeFilters;
    }
    globalState.closeLoraDetail(index);
}

function handleImageDetailClose(index) {
    globalState.closeImageDetail(index);
}

function handleSearchResultsClose() {
    globalState.closeSearchResults();
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
        :initial-path="currentPath"  
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

    <!-- 添加 Lora 组合模块 -->
    <template v-else-if="currentModule === 'combination'">
      <div class="module-content combination-module-content">
        <LoraCombinationView />
      </div>
    </template>

    <!-- 导航菜单 -->
    <NavigationMenu 
      :current-module="currentModule"
      @module-change="handleModuleChange"
    />

    <!-- 修改 LoraDetail 部分，使用 v-for 渲染多个面板 -->
    <template v-for="(detail, index) in globalState.loraDetailStack?.value || []" :key="`lora-${index}`">
        <LoraDetail 
            :lora="detail.lora"
            :show="true"
            :current-path="currentPath"
            :style="{ zIndex: detail.zIndex }"
            @close="() => handleLoraDetailClose(index)"
            @refresh="() => {}"
        />
    </template>
    
    <template v-for="(detail, index) in globalState.imageDetailStack?.value || []" :key="`image-${index}`">
        <ImageDetail 
            :image-url="detail.imageUrl"
            :show="true"
            :style="{ zIndex: detail.zIndex }"
            @close-image-detail="() => handleImageDetailClose(index)"
        />
    </template>

    <!-- 添加搜索结果组件 -->
    <LoraSearchResult
        :search-results="globalState.searchResults.value"
        :show="globalState.showSearchResults.value"
        :search-term="globalState.searchTerm.value"
        @close="handleSearchResultsClose"
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

.combination-module-content {
  padding: 2rem;
  padding-bottom: 6rem;
  margin: 0 auto;
  max-width: 1200px;
}
</style>
