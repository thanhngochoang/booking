package com.paditech.mvpbase.common.dialog;

import android.view.View;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.utils.StringUtil;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 6/28/2017.
 */

public class MessageDialog extends BaseDialog {
    @BindView(R.id.tv_message)
    TextView mTvMessage;
    @BindView(R.id.btn_ok)
    TextView mBtnOk;
    @BindView(R.id.btn_cancel)
    TextView mBtnCancel;
    @BindView(R.id.line)
    View mLine;

    private OnPositiveClickListener mOnPositiveClickListener;
    private OnNegativeClickListener mOnNegativeClickListener;
    private String message, okText, cancelText;
    private boolean hasTitle;


    public static MessageDialog newInstance(boolean hasTitle, String message) {
        MessageDialog messageDialog = new MessageDialog();
        messageDialog.message = message;
        messageDialog.hasTitle = hasTitle;
        return messageDialog;
    }

    public static MessageDialog newInstance(boolean hasTitle, String message, String ok) {
        MessageDialog messageDialog = new MessageDialog();
        messageDialog.message = message;
        messageDialog.okText = ok;
        messageDialog.hasTitle = hasTitle;
        return messageDialog;
    }

    public static MessageDialog newInstance(boolean hasTitle, String message, String ok, String cancelText) {
        MessageDialog messageDialog = new MessageDialog();
        messageDialog.message = message;
        messageDialog.okText = ok;
        messageDialog.cancelText = cancelText;
        messageDialog.hasTitle = hasTitle;
        return messageDialog;
    }

    public void setmOnPositiveClickListener(OnPositiveClickListener mOnPositiveClickListener) {
        this.mOnPositiveClickListener = mOnPositiveClickListener;
    }

    public void setmOnNegativeClickListener(OnNegativeClickListener mOnNegativeClickListener) {
        this.mOnNegativeClickListener = mOnNegativeClickListener;
    }

    @Override
    protected int getContentView() {
        return R.layout.dialog_message;
    }

    @Override
    protected void initView(View view) {
        if (!StringUtil.isEmpty(message)) {
            mTvMessage.setText(message);
        }
        if (!StringUtil.isEmpty(okText)) {
            mBtnOk.setText(okText);
        }

        if (!StringUtil.isEmpty(cancelText)) {
            mLine.setVisibility(View.VISIBLE);
            mBtnCancel.setVisibility(View.VISIBLE);
            mBtnCancel.setText(cancelText);
        } else {
            mBtnCancel.setVisibility(View.GONE);
            mLine.setVisibility(View.GONE);
        }
    }

    @OnClick(R.id.btn_ok)
    public void onPositive() {
        dismiss();
        if (mOnPositiveClickListener != null) mOnPositiveClickListener.onPositiveClick();
    }

    @OnClick(R.id.btn_cancel)
    public void onNegative() {
        dismiss();
        if (mOnNegativeClickListener != null) mOnNegativeClickListener.onNegativeClick();
    }
}
