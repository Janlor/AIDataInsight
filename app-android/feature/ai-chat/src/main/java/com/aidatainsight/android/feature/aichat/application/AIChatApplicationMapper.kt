package com.aidatainsight.android.feature.aichat.application

import com.aidatainsight.android.core.model.contract.ChartPayload
import com.aidatainsight.android.core.model.contract.ChartSeries
import com.aidatainsight.android.core.model.contract.ChartUnit
import com.aidatainsight.android.core.model.contract.ConversationContentKind
import com.aidatainsight.android.core.model.contract.ConversationMessage
import com.aidatainsight.android.core.model.contract.ConversationRole
import com.aidatainsight.android.core.model.contract.FeedbackState
import com.aidatainsight.android.core.model.contract.FunctionArguments
import com.aidatainsight.android.core.model.contract.FunctionModel
import com.aidatainsight.android.core.model.contract.FunctionName
import com.aidatainsight.android.core.model.contract.HistoryChartDetail
import com.aidatainsight.android.core.model.contract.HistoryContentType
import com.aidatainsight.android.core.model.contract.HistoryDetail
import com.aidatainsight.android.core.model.contract.HistoryDetailType
import com.aidatainsight.android.core.network.client.AIDataInsightHttpClientFactory
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object AIChatApplicationMapper {
    private const val CHART_FALLBACK_MESSAGE = "数据分析还在测试阶段，很快就能上线，敬请期待！"
    private const val DEFAULT_ASSISTANT_MESSAGE = "新版本上线啦，升级后我会变得更聪明，快来体验吧！"

    fun makeMessages(detailList: List<HistoryDetail>): List<ConversationMessage> {
        // 将后端历史明细转换为聊天页面统一消息模型。
        return detailList.map(::mapToMessage)
    }

    fun makeChartPayload(model: HistoryChartDetail): ChartPayload? {
        // 普通图表是一组单值项，转换成每项一个 series 便于 UI 统一渲染。
        model.chartCommonVoList?.takeIf { it.isNotEmpty() }?.let { list ->
            return ChartPayload(
                functionName = model.funcType,
                unit = unitFor(model.funcType),
                series = list.map { item ->
                    val title = item.name.orEmpty()
                    ChartSeries(
                        xAxis = title,
                        labels = listOf(title),
                        values = listOf(item.value ?: 0.0),
                    )
                },
                emptyMessage = null,
            )
        }

        model.accountAgeGroupVoList?.takeIf { it.isNotEmpty() }?.let { list ->
            val first = list.first()
            if (first.chartType == "2" && first.msg != null) {
                // 账龄接口用 chartType=2 表示无图表但有说明文案。
                return ChartPayload(
                    functionName = model.funcType,
                    unit = unitFor(model.funcType),
                    series = emptyList(),
                    emptyMessage = first.msg,
                )
            }

            return ChartPayload(
                functionName = model.funcType,
                unit = unitFor(model.funcType),
                series = list.map { item ->
                    ChartSeries(
                        xAxis = item.name.orEmpty(),
                        labels = item.labelList.orEmpty(),
                        values = item.valueList.orEmpty(),
                    )
                },
                emptyMessage = null,
            )
        }

        return null
    }

    fun makeFunctionModel(data: JsonObject): FunctionModel {
        // /chat/function 返回的 arguments 结构依赖 name，需要按函数名手动解码。
        val name = data["name"]?.jsonPrimitive?.contentOrNull?.let(FunctionName::fromRawValue)
        return FunctionModel(
            historyId = data["historyId"]?.jsonPrimitive?.intOrNull,
            hasTool = data["hasTool"]?.jsonPrimitive?.booleanOrNull,
            name = name,
            msg = data["msg"]?.jsonPrimitive?.contentOrNull,
            arguments = decodeFunctionArguments(name, data["arguments"] as? JsonObject),
        )
    }

    fun decodeFunctionContent(content: String): FunctionModel? {
        val element = runCatching {
            AIDataInsightHttpClientFactory.json.parseToJsonElement(content).jsonObject
        }.getOrNull() ?: return null
        return runCatching { makeFunctionModel(element) }.getOrNull()
    }

    fun decodeChartContent(content: String): HistoryChartDetail? {
        return runCatching {
            AIDataInsightHttpClientFactory.json.decodeFromString(
                HistoryChartDetail.serializer(),
                content,
            )
        }.getOrNull()
    }

    fun chartFallbackMessage(): String = CHART_FALLBACK_MESSAGE

    private fun mapToMessage(model: HistoryDetail): ConversationMessage {
        if (model.type == HistoryDetailType.Question) {
            return ConversationMessage(
                id = messageId(model),
                role = ConversationRole.User,
                contentKind = ConversationContentKind.Text,
                text = model.content.orEmpty(),
                intentType = null,
                chartPayload = null,
                feedback = FeedbackState.None,
                historyDetailId = model.id,
                functionName = null,
            )
        }

        val content = model.content
        if (model.type == HistoryDetailType.Answer &&
            model.contentType == HistoryContentType.Chart &&
            content != null
        ) {
            // 历史图表内容存储为 JSON 字符串，进入 UI 前恢复成强类型图表载荷。
            val chartDetail = decodeChartContent(content)
            if (chartDetail != null) {
                val payload = makeChartPayload(chartDetail)
                if (payload != null && payload.series.isNotEmpty()) {
                    return ConversationMessage(
                        id = messageId(model),
                        role = ConversationRole.Assistant,
                        contentKind = ConversationContentKind.Chart,
                        text = "根据您的查询，以下是分析结果:",
                        intentType = null,
                        chartPayload = payload,
                        feedback = feedbackFrom(model.isLike),
                        historyDetailId = model.id,
                        functionName = chartDetail.funcType,
                    )
                }
                return assistantTextMessage(model, payload?.emptyMessage ?: CHART_FALLBACK_MESSAGE)
            }
            return assistantTextMessage(model, CHART_FALLBACK_MESSAGE)
        }

        if (model.type == HistoryDetailType.Answer &&
            model.contentType == HistoryContentType.Ai &&
            content != null
        ) {
            decodeFunctionContent(content)?.let { functionModel ->
                return assistantTextMessage(model, functionModel.msg.orEmpty())
            }
        }

        return assistantTextMessage(model, content ?: DEFAULT_ASSISTANT_MESSAGE)
    }

    private fun decodeFunctionArguments(
        name: FunctionName?,
        arguments: JsonObject?,
    ): FunctionArguments? {
        if (name == null || arguments == null) return null
        val json = AIDataInsightHttpClientFactory.json
        return runCatching {
            when (name.argumentKind) {
                com.aidatainsight.android.core.model.contract.FunctionArgumentKind.Basic ->
                    FunctionArguments.Basic(json.decodeFromJsonElement(com.aidatainsight.android.core.model.contract.BasicQuery.serializer(), arguments))
                com.aidatainsight.android.core.model.contract.FunctionArgumentKind.TimeRange ->
                    FunctionArguments.TimeRange(json.decodeFromJsonElement(com.aidatainsight.android.core.model.contract.TimeRangeQuery.serializer(), arguments))
                com.aidatainsight.android.core.model.contract.FunctionArgumentKind.Warehouse ->
                    FunctionArguments.Warehouse(json.decodeFromJsonElement(com.aidatainsight.android.core.model.contract.WarehouseQuery.serializer(), arguments))
                com.aidatainsight.android.core.model.contract.FunctionArgumentKind.AccountAge ->
                    FunctionArguments.AccountAge(json.decodeFromJsonElement(com.aidatainsight.android.core.model.contract.AccountAgeQuery.serializer(), arguments))
                com.aidatainsight.android.core.model.contract.FunctionArgumentKind.PerformanceType ->
                    FunctionArguments.PerformanceType(json.decodeFromJsonElement(com.aidatainsight.android.core.model.contract.PerformanceTypeQuery.serializer(), arguments))
            }
        }.getOrNull()
    }

    private fun assistantTextMessage(model: HistoryDetail, text: String): ConversationMessage {
        return ConversationMessage(
            id = messageId(model),
            role = ConversationRole.Assistant,
            contentKind = ConversationContentKind.Text,
            text = text,
            intentType = null,
            chartPayload = null,
            feedback = feedbackFrom(model.isLike),
            historyDetailId = model.id,
            functionName = null,
        )
    }

    private fun feedbackFrom(isLike: String?): FeedbackState {
        return when (isLike) {
            "1" -> FeedbackState.Liked
            "0" -> FeedbackState.Disliked
            null -> FeedbackState.None
            else -> FeedbackState.Unknown
        }
    }

    private fun messageId(model: HistoryDetail): String {
        return model.id?.let { "history-detail-$it" } ?: "history-detail-${model.hashCode()}"
    }

    private fun unitFor(functionName: FunctionName?): ChartUnit {
        // 库存类函数以吨为单位，其余经营分析默认按金额展示。
        return when (functionName) {
            FunctionName.QueryStockGroupByOrg,
            FunctionName.QueryStockGroupByWarehouse,
            -> ChartUnit.Ton
            else -> ChartUnit.Currency
        }
    }
}
