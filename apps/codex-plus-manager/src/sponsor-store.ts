/** 两个「添加供应商」目录共用本 fork 的固定 UGQai 预设；远端数据不改变本地配置。 */
import { useMemo, useSyncExternalStore } from "react";
import { sponsorPresets, type ProviderPreset, type SponsorAdsPayload } from "./presets";

let adsPayload: SponsorAdsPayload = null;
const listeners = new Set<() => void>();

export function setSponsorAds(payload: SponsorAdsPayload) {
  adsPayload = payload;
  for (const listener of listeners) listener();
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function useSponsorPresets(): ProviderPreset[] {
  const payload = useSyncExternalStore(subscribe, () => adsPayload);
  return useMemo(() => sponsorPresets(payload), [payload]);
}
