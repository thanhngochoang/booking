package com.paditech.mvpbase.common.base;

import android.animation.ObjectAnimator;
import android.annotation.SuppressLint;
import android.view.View;
import android.view.animation.DecelerateInterpolator;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.common.view.ValueProgressBar;

import butterknife.BindView;

/**
 * Created by ThanhNgocHoang on 9/18/2017.
 */

public abstract class WebViewActivity extends MVPActivity {

    @BindView(R.id.web_view)
    WebView mWebView;
    @BindView(R.id.progressBar)
    ValueProgressBar mProgressLoading;

    protected abstract String getUrl();

    @Override
    protected int getContentView() {
        return R.layout.act_webview;
    }

    @Override
    protected void initView() {
        mWebView.setScrollBarStyle(View.SCROLLBARS_INSIDE_OVERLAY);
        mWebView.setWebViewClient(new WebViewClient() {

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                //  mProgressBar.setVisibility(View.GONE);
            }
        });
        mWebView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                if (newProgress == 100) {
                    mProgressLoading.setVisibility(View.GONE);
                    mProgressLoading.setProgress(100);
                } else {
                    mProgressLoading.setVisibility(View.VISIBLE);
                    // will update the "progress" propriety of seekbar until it reaches progress
                    ObjectAnimator animation = ObjectAnimator.ofInt(mProgressLoading, "progress", newProgress);
                    animation.setDuration(500); // 0.5 second
                    animation.setInterpolator(new DecelerateInterpolator());
                    animation.start();
                }
            }
        });
        WebSettings settings = mWebView.getSettings();
        enableJavaScript();
        settings.setLoadsImagesAutomatically(true);
        if (!StringUtil.isEmpty(getUrl()))
            mWebView.loadUrl(getUrl());
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void enableJavaScript() {
        mWebView.getSettings().setJavaScriptEnabled(true);
    }

}
