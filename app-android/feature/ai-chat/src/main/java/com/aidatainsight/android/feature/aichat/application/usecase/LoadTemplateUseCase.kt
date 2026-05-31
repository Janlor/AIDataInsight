package com.aidatainsight.android.feature.aichat.application.usecase

import com.aidatainsight.android.feature.aichat.application.model.LoadTemplateOutput
import com.aidatainsight.android.feature.aichat.domain.AIChatRepository

class LoadTemplateUseCase(
    private val repository: AIChatRepository,
) {
    /** 加载欢迎态推荐问题。 */
    suspend operator fun invoke(): LoadTemplateOutput {
        val template = repository.loadTemplate()
        return LoadTemplateOutput(questions = template.questions)
    }
}
