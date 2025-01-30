import { ref } from 'vue'

export const globalLoraMap = ref(new Map())
export const loraNameMap = ref(new Map())

export function updateLoraData(loraFiles) {
    globalLoraMap.value.clear()
    loraNameMap.value.clear()
    
    loraFiles.forEach(lora => {
        // 存储完整信息
        globalLoraMap.value.set(lora.name, lora)
        
        // 处理名称映射
        const baseName = lora.name.replace('.safetensors', '')
        // 提取基础名称（移除 -00040 这样的训练次数）
        const mainName = baseName.replace(/-\d+$/, '')
        
        // 存储两种方式的映射
        loraNameMap.value.set(baseName, lora)
        loraNameMap.value.set(mainName, lora)
    })
}

export function findLoraByName(name) {
    return loraNameMap.value.get(name) || globalLoraMap.value.get(name)
}

export function getAllLoras() {
    return Array.from(globalLoraMap.value.values())
}

// 添加全局状态管理
export const globalState = {
    // LoraDetail 相关
    selectedLora: ref(null),
    showLoraDetail: ref(false),
    
    // ImageDetail 相关
    selectedImageUrl: ref(''),
    showImageDetail: ref(false),

    // 控制方法
    openLoraDetail(lora) {
        this.selectedLora.value = lora;
        this.showLoraDetail.value = true;
    },

    closeLoraDetail() {
        this.showLoraDetail.value = false;
        this.selectedLora.value = null;
    },

    openImageDetail(imageUrl) {
        this.selectedImageUrl.value = imageUrl;
        this.showImageDetail.value = true;
    },

    closeImageDetail() {
        this.showImageDetail.value = false;
        this.selectedImageUrl.value = '';
    }
}
