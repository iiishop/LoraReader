import { ref } from 'vue'

// 当前页面的 LoRA 映射
export const globalLoraMap = ref(new Map())
export const loraNameMap = ref(new Map())

// 全局所有 LoRA 的映射
export const allLoraMap = ref(new Map())
export const allLoraNameMap = ref(new Map())

// 更新当前页面的 LoRA 数据
export function updateLoraData(loraFiles) {
    globalLoraMap.value.clear()
    loraNameMap.value.clear()
    
    loraFiles.forEach(lora => {
        globalLoraMap.value.set(lora.name, lora)
        const baseName = lora.name.replace('.safetensors', '')
        const mainName = baseName.replace(/-\d+$/, '')
        loraNameMap.value.set(baseName, lora)
        loraNameMap.value.set(mainName, lora)
    })
}

// 初始化全局 LoRA 数据
export async function initializeAllLoras() {
    try {
        const response = await fetch('http://localhost:5000/scan-all-loras')
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`)
        }
        const data = await response.json()
        
        allLoraMap.value.clear()
        allLoraNameMap.value.clear()

        data.lora_files.forEach(lora => {
            allLoraMap.value.set(lora.name, lora)
            const baseName = lora.name.replace('.safetensors', '')
            const mainName = baseName.replace(/-\d+$/, '')
            allLoraNameMap.value.set(baseName, lora)
            allLoraNameMap.value.set(mainName, lora)
        })
        
        console.log(`Initialized ${allLoraMap.value.size} global LoRAs`)
        return true
    } catch (err) {
        console.error('Error initializing all LoRAs:', err)
        return false
    }
}

// 修改查找函数使用全局映射
export function findLoraByName(name) {
    console.log('Finding LoRA by name:', name)
    
    const cleanName = name.toLowerCase()
        .replace(/\.safetensors$/, '')
        .replace(/^(?:lora|lyco)_/, '')  // 移除 lora_ 或 lyco_ 前缀
        .replace(/<[^>]*>/g, '')
        .trim()
    
    console.log('Cleaned name:', cleanName)
    
    // 首先在全局映射中查找
    let lora = allLoraNameMap.value.get(cleanName)
    if (lora) {
        console.log('Found in global map')
        return lora
    }
    
    // 在全局映射中进行模糊匹配
    for (const [key, value] of allLoraNameMap.value.entries()) {
        const cleanKey = key.toLowerCase()
        if (cleanKey.includes(cleanName) || cleanName.includes(cleanKey)) {
            console.log('Found by fuzzy match in global map:', key)
            return value
        }
    }
    
    console.log('No LoRA found')
    return null
}

export function getAllLoras() {
    return Array.from(globalLoraMap.value.values())
}

// 添加记录点击的函数
async function recordLoraClick(loraName, searchTerm = null) {
    try {
        const response = await fetch('http://localhost:5000/lora-click', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ 
                lora_name: loraName,
                search_term: searchTerm 
            })
        });
        
        if (response.ok) {
            return await response.json();
        }
    } catch (err) {
        console.error('Error recording click:', err);
    }
    return null;
}

// 添加全局状态管理
export const globalState = {
    loraDetailStack: ref([]),
    imageDetailStack: ref([]), // 新增图片详情栈

    async openLoraDetail(lora) {
        // 记录点击并更新所有相关状态
        const newClicks = await recordLoraClick(
            lora.name, 
            lora.searchTerm // 传递搜索词
        );
        
        if (newClicks !== null) {
            // 更新点击数
            if (lora.searchTerm) {
                lora.search_clicks = newClicks.search_clicks;
            }
            lora.global_clicks = newClicks.global_clicks;
            
            // 更新搜索结果中相同 lora 的点击数
            if (this.searchResults.value) {
                const resultLora = this.searchResults.value.find(l => l.name === lora.name);
                if (resultLora) {
                    if (lora.searchTerm) {
                        resultLora.search_clicks = newClicks.search_clicks;
                    }
                    resultLora.global_clicks = newClicks.global_clicks;
                }
            }
            
            // 更新全局映射中的点击数
            const globalLora = allLoraMap.value.get(lora.name);
            if (globalLora) {
                globalLora.global_clicks = newClicks.global_clicks;
            }
        }
        
        const baseZIndex = 1000;
        const stackLength = this.loraDetailStack.value.length + this.imageDetailStack.value.length;
        this.loraDetailStack.value.push({
            lora,
            zIndex: baseZIndex + stackLength * 2 // 使用2的倍数，确保新的详情面板总是在当前层级之上
        });
    },

    closeLoraDetail(index = -1) {
        if (index === -1) {
            this.loraDetailStack.value.pop();
        } else {
            this.loraDetailStack.value.splice(index, 1);
        }
    },

    openImageDetail(imageUrl) {
        const baseZIndex = 1000;
        const stackLength = this.loraDetailStack.value.length + this.imageDetailStack.value.length;
        this.imageDetailStack.value.push({
            imageUrl,
            zIndex: baseZIndex + stackLength * 2 + 1 // 使用奇数，确保在最近的 LoraDetail 之上
        });
    },

    closeImageDetail(index = -1) {
        if (index === -1) {
            this.imageDetailStack.value.pop();
        } else {
            this.imageDetailStack.value.splice(index, 1);
        }
    },

    // 添加搜索结果状态管理
    searchResults: ref([]),
    showSearchResults: ref(false),
    searchTerm: ref(''),
    searchMode: ref('browse'),  // 'browse', 'select', 'custom'
    searchCallback: null,
    searchCallbackType: null,  // 用于标识回调类型
    
    // 添加新方法
    openSearchResults(results, searchTerm, callbackOrType, type = null) {
        this.searchResults.value = results;
        this.searchTerm.value = searchTerm;
        this.showSearchResults.value = true;

        if (typeof callbackOrType === 'function') {
            // 如果传入的是函数，则视为回调
            this.searchCallback = callbackOrType;
            this.searchMode.value = 'custom';
            this.searchCallbackType = type;
        } else if (callbackOrType === true) {
            // 兼容旧的用法，true 表示选择模式
            this.searchMode.value = 'select';
        } else {
            // 默认为浏览模式
            this.searchMode.value = 'browse';
        }
    },
    
    closeSearchResults() {
        this.showSearchResults.value = false;
        this.searchResults.value = [];
        this.searchTerm.value = '';
        this.searchCallback = null;
        this.searchMode.value = 'browse';
        this.searchCallbackType = null;
    }
};

// 添加初始化检查函数并确保导出
export function initGlobalState() {
    if (!globalState.loraDetailStack?.value) {
        globalState.loraDetailStack.value = [];
    }
    if (!globalState.imageDetailStack?.value) {
        globalState.imageDetailStack.value = [];
    }
    if (!globalState.searchResults?.value) {
        globalState.searchResults.value = [];
    }
    
    console.log('Global state initialized');
    return true;
}

// 优化的相似度计算函数
function calculateSimilarity(str1, str2) {
    const s1 = str1.toLowerCase();
    const s2 = str2.toLowerCase();
    
    // 精确匹配给予最高分
    if (s1 === s2) return 1;
    
    // 如果搜索词完整出现在名称中，给予较高分数
    if (s1.includes(s2)) {
        // 根据匹配位置给予不同权重
        const position = s1.indexOf(s2);
        if (position === 0) return 0.95; // 开头匹配
        if (position === s1.length - s2.length) return 0.9; // 结尾匹配
        return 0.85; // 中间匹配
    }
    
    // 如果名称完整出现在搜索词中
    if (s2.includes(s1)) return 0.8;
    
    // 计算编辑距离相似度
    const distance = levenshteinDistance(s1, s2);
    const maxLength = Math.max(s1.length, s2.length);
    const similarity = 1 - (distance / maxLength);
    
    return similarity * 0.7; // 降低模糊匹配的权重
}

// 编辑距离算法
function levenshteinDistance(str1, str2) {
    const m = str1.length;
    const n = str2.length;
    const dp = Array.from({ length: m + 1 }, () => 
        Array.from({ length: n + 1 }, () => 0)
    );

    for (let i = 0; i <= m; i++) dp[i][0] = i;
    for (let j = 0; j <= n; j++) dp[0][j] = j;

    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            if (str1[i - 1] === str2[j - 1]) {
                dp[i][j] = dp[i - 1][j - 1];
            } else {
                dp[i][j] = Math.min(
                    dp[i - 1][j - 1] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j] + 1
                );
            }
        }
    }
    return dp[m][n];
}

// 改进的搜索函数 - 移除分页限制
export function findLorasByName(searchTerm) {
    const normalizedTerm = normalizeSearchTerm(searchTerm);
    console.log('Normalized search term:', normalizedTerm);
    
    // 清理和分割搜索词
    const keywords = normalizedTerm
        .split(/[\s-_]+/)
        .filter(k => k.length > 0);
    
    console.log('Search keywords:', keywords);
    
    // 搜索结果对象数组
    const results = [];
    const processedNames = new Set();
    
    // 遍历所有项进行匹配
    for (const [key, lora] of allLoraNameMap.value.entries()) {
        if (processedNames.has(lora.name)) continue;
        processedNames.add(lora.name);
        
        const cleanKey = key.toLowerCase();
        let nameScore = 0;
        
        // 计算名称匹配分数
        for (const keyword of keywords) {
            const similarity = calculateSimilarity(cleanKey, keyword);
            nameScore = Math.max(nameScore, similarity);
        }
        
        // 如果名称匹配分数过低，跳过
        if (nameScore < 0.3) continue;
        
        // 计算元数据匹配分数
        const metadataScore = calculateMetadataScore(lora, keywords);
        
        // 计算最终分数（名称匹配占主要权重）
        const finalScore = nameScore * 0.8 + metadataScore * 0.2;
        
        // 确保包含点击量信息
        results.push({
            ...lora,  // 包含所有原始 lora 信息
            score: finalScore,
            nameScore,
            metadataScore,
            searchTerm: normalizedTerm  // 添加搜索词以便后续使用
        });
    }
    
    // 先按相关度排序
    return results
        .sort((a, b) => {
            const scoreDiff = b.nameScore - a.nameScore;
            if (Math.abs(scoreDiff) > 0.1) return scoreDiff;
            return b.score - a.score;
        })
        .map(r => r);  // 返回完整对象而不是只返回 lora
}

// 优化元数据匹配分数计算
function calculateMetadataScore(lora, keywords) {
    let score = 0;
    const metadata = lora.metadata || {};
    const config = lora.config || {};
    
    const searchableFields = {
        // 权重更高的字段
        highPriority: [
            metadata.ss_base_model_version,
            config.activation_text
        ],
        // 权重较低的字段
        lowPriority: [
            metadata.ss_network_module,
            config.notes,
            config.description
        ]
    };
    
    // 对每个关键词在每个字段中进行搜索
    for (const keyword of keywords) {
        // 高优先级字段匹配
        for (const field of searchableFields.highPriority) {
            if (field && String(field).toLowerCase().includes(keyword)) {
                score += 0.15;
            }
        }
        
        // 低优先级字段匹配
        for (const field of searchableFields.lowPriority) {
            if (field && String(field).toLowerCase().includes(keyword)) {
                score += 0.05;
            }
        }
    }
    
    return Math.min(score, 1);
}

// 添加搜索词规范化函数
function normalizeSearchTerm(term) {
    return term.toLowerCase()
        .replace(/\.safetensors$/, '')
        .replace(/^(?:lora|lyco)_/, '')
        .replace(/<[^>]*>/g, '')
        .replace(/[\s-]+/g, '_')  // 将空格和连字符统一转换为下划线
        .trim();
}
