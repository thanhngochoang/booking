package com.paditech.mvpbase.common.dialog;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Handler;
import android.support.v4.content.ContextCompat;
import android.support.v7.widget.CardView;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;


import com.paditech.mvpbase.R;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 12/4/2017.
 */

public class ToastPopup extends PopupWindow {
    public static final int DURATION_DISMISS = 2000;
    @BindView(R.id.icon)
    ImageView icon;
    @BindView(R.id.tv_message)
    TextView tvMessage;
    @BindView(R.id.card_view)
    CardView cardView;

    private Context mContext;
    private String mMessage;
    private ToastType mToastType = ToastType.ALERT;

    public ToastPopup(Context context) {
        super(context);
        this.mContext = context;
        initView();
    }

    private void initView() {
        try {
            View view = LayoutInflater.from(mContext).inflate(R.layout.dialog_toast, null);
            ButterKnife.bind(this, view);
            int width = LinearLayout.LayoutParams.WRAP_CONTENT;
            int height = LinearLayout.LayoutParams.WRAP_CONTENT;
            setContentView(view);
            setWidth(width);
            setHeight(height);
            setAnimationStyle(R.anim.show_popup);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                setAttachedInDecor(true);
            }
            setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            tvMessage.setText(mMessage);
            icon.setImageResource(mToastType.getIcon());
            cardView.setCardBackgroundColor(ContextCompat.getColor(mContext, mToastType.getColor()));
            setAnimationStyle(R.style.PopupAnimation);
            if (Build.VERSION.SDK_INT >= 26) {
                setWindowLayoutType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY);
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                setWindowLayoutType(WindowManager.LayoutParams.TYPE_TOAST);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }


    }

    public void show(View parent, String message, ToastType toastType) {
        try {
            this.mMessage = message;
            this.mToastType = toastType;
            if (tvMessage != null) tvMessage.setText(mMessage);
            if (icon != null) {
                icon.setImageResource(mToastType.getIcon());
            }
            if (cardView != null)
                cardView.setCardBackgroundColor(ContextCompat.getColor(mContext, mToastType.getColor()));
            showAtLocation(parent, Gravity.BOTTOM, 0, 0);
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    try {
                        dismiss();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }, DURATION_DISMISS);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void makeText(Context context, View view, String message, ToastType toastType) {
        ToastPopup toastPopup = new ToastPopup(context);
        toastPopup.show(view, message, toastType);
    }

    public enum ToastType {
        ALERT(R.drawable.ic_cloud_done_white_30dp, R.color.green), ERROR(R.drawable.ic_error_white_40dp, R.color.pink);

        private int icon, color;

        ToastType(int icon, int color) {
            this.icon = icon;
            this.color = color;
        }

        public int getIcon() {
            return icon;
        }

        public int getColor() {
            return color;
        }
    }
}
