import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AdMobService {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdLoading = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
  }

  static void _loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  static Future<void> showRewardedAdIfAvailable({
    required BuildContext context,
    required VoidCallback onProceed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastAdDate = prefs.getString('last_rewarded_ad_date');

    // Strict 1 ad per day per user
    if (lastAdDate == todayStr) {
      onProceed();
      return;
    }

    if (_rewardedAd == null) {
      // Ad not ready, just proceed
      onProceed();
      _loadRewardedAd(); // Try loading for next time
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // pre-load next ad
        onProceed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        onProceed();
      },
    );

    await prefs.setString('last_rewarded_ad_date', todayStr);
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      // Reward earned logic if any
    });
  }

  static BannerAd createBannerAd({
    required VoidCallback onAdLoaded,
    required Function(LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onAdLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    );
  }
}
