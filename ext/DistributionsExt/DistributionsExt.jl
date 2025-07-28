module DistributionsExt

using Distributions, MessagePassingRulesBase

import MessagePassingRulesBase: sdtype

# We consider all objects from the `Distributions` package to be stochastic
MessagePassingRulesBase.sdtype(::Type{<:Distribution}) = MessagePassingRulesBase.Stochastic()
MessagePassingRulesBase.sdtype(::Distribution)         = MessagePassingRulesBase.Stochastic()

end