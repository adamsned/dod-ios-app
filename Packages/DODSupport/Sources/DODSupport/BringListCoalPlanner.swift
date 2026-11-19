import Foundation

/// DUT-979 - how many briquettes to pack for a cookout.
public enum BringListCoalPlanner {
    /// Max servings one Dutch oven is assumed to feed.
    public static let servingsPerOven = 8
    /// Extra coals for refreshing the bed, expressed as a fraction of the initial count.
    public static let refreshBufferPercent = 50

    /// Oven count: ceil(servings / servingsPerOven), minimum 1. nil/<=0 servings -> 1.
    public static func ovenCount(servings: Int?) -> Int {
        guard let servings, servings > 0 else { return 1 }
        return (servings + servingsPerOven - 1) / servingsPerOven
    }

    /// Total briquettes to pack: per-oven total x ovens, plus refreshBufferPercent, rounded up.
    public static func briquettesToPack(
        servings: Int?,
        ovenTempF: Int = 350,
        ovenDiameterInches: Int = 12,
        task: CharcoalRecipeConverter.CookTask = .bake
    ) -> Int {
        let per = CharcoalRecipeConverter.recommend(
            ovenTempF: ovenTempF,
            ovenDiameterInches: ovenDiameterInches,
            task: task
        ).totalBriquettes
        let base = per * ovenCount(servings: servings)
        return base + (base * refreshBufferPercent + 99) / 100
    }
}
